//
//  ConnectionThread.m
//  mqttitude
//
//  Created by Christoph Krey on 20.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "ConnectionThread.h"

@interface ConnectionThread()
@property (strong, nonatomic) NSTimer *reconnectTimer;
@property (nonatomic) float reconnectTime;
@property (strong, nonatomic) NSTimer *inactivityTimer;
@property (strong, nonatomic) NSTimer *ticklerTimer;
@property (nonatomic) NSInteger state;

@property (strong, nonatomic) MQTTSession *session;
@property (strong, nonatomic) NSMutableArray *fifo;


@property (strong, nonatomic) NSString *host;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *pass;
@property (strong, nonatomic) NSString *topic;
@property (strong, nonatomic) NSString *willTopic;
@property (strong, nonatomic) NSData *willMessage;
@property (nonatomic) BOOL tls;
@property (nonatomic) BOOL auth;
@property (nonatomic) NSInteger port;
@property (nonatomic) BOOL retainFlag;
@property (nonatomic) NSInteger qos;
@end

@implementation ConnectionThread

enum state {
    state_waiting,
    state_connecting,
    state_error,
    state_connected,
    state_closing,
    state_exit
};

/*
 *  Timers in seconds
 */
#define RECONNECT_TIMER 1.0
#define RECONNECT_TIMER_MAX 300.0

#define INACTIVITY_TIMER 15.0
#define TICKLER_TIMER 60*60

- (void)setState:(NSInteger)state
{
    _state = state;
    NSLog(@"Connection thread state:%d", self.state);
    [self showIndicator];
}

- (NSArray *)fifo
{
    if (!_fifo)
        _fifo = [[NSMutableArray alloc] init];
    return _fifo;
}

- (void)main
{
    self.ticklerTimer = [NSTimer timerWithTimeInterval:TICKLER_TIMER
                                                target:self selector:@selector(tickler)
                                              userInfo:Nil repeats:TRUE];
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
    [runLoop addTimer:self.ticklerTimer
              forMode:NSDefaultRunLoopMode];
    
    self.reconnectTime = RECONNECT_TIMER;
    
    do
    {
        if (self.state == state_connected) {
            if ([self.fifo count]) {
                /*
                 * if there are some queued send messages, send them
                 */
                NSDictionary *parameters = self.fifo[0];
                [self.fifo removeObjectAtIndex:0];
                [self sendData:parameters];
            } else {
                /*
                 * otherwise start inactivity timer if necessary
                 */
                if (!self.inactivityTimer || !self.inactivityTimer.isValid) {
                    self.inactivityTimer = [NSTimer timerWithTimeInterval:INACTIVITY_TIMER
                                                                   target:self selector:@selector(inactivity)
                                                                 userInfo:Nil repeats:FALSE];
                    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
                    [runLoop addTimer:self.inactivityTimer
                              forMode:NSDefaultRunLoopMode];
                }
            }
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
    }
    while (self.state != state_exit);
}


- (void)reconnect
{
    NSLog(@"reconnect");

    self.reconnectTimer = nil;
    self.state = state_waiting;

    [self connectToInternal];
}

- (void)inactivity
{
    NSLog(@"inactivity");

    self.inactivityTimer = nil;
    [self disconnect];
}
    
- (void)tickler
{
    NSLog(@"tickler");
    self.reconnectTime = RECONNECT_TIMER;

    [self connectToInternal];
}

/*
 * externally visible methods
 */

#define OTHERS @"#"
#define MQTT_KEEPALIVE 10

- (void)connectTo:(NSDictionary *)parameters
{
    self.host = parameters[@"HOST"];
    self.port = [parameters[@"PORT"] intValue];
    self.tls = [parameters[@"TLS"] boolValue];
    self.auth = [parameters[@"AUTH"] boolValue];
    self.user = parameters[@"USER"];
    self.pass = parameters[@"PASS"];
    self.willTopic = parameters[@"TOPIC"];
    self.topic = parameters[@"TOPIC"];
    self.willMessage = parameters[@"DATA"];
    
    self.reconnectTime = RECONNECT_TIMER;
    
    [self connectToInternal];
}

- (void)connectToInternal
{
    if (self.state == state_waiting) {
        NSString *clientId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        
        self.session = [[MQTTSession alloc] initWithClientId:clientId
                                                    userName:self.auth ? self.user : @""
                                                    password:self.auth ? self.pass : @""
                                                   keepAlive:MQTT_KEEPALIVE
                                                cleanSession:YES
                                                   willTopic:self.willTopic
                                                     willMsg:self.willMessage
                                                     willQoS:1
                                              willRetainFlag:YES];
        
        self.state = state_connecting;
        [self.session setDelegate:self];
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
        [self.session subscribeTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]];
        [self.session subscribeTopic:[NSString stringWithFormat:OTHERS]];
    } else {
        NSLog(@"MQTTitude not waiting, can't connect");
    }
}



- (void)disconnect
{
    if (self.state == state_connected) {
        self.state = state_closing;
        [self.session unsubscribeTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]];
        [self.session unsubscribeTopic:[NSString stringWithFormat:OTHERS]];
        [self.session close];
    } else {
        self.state = state_waiting;
        NSLog(@"MQTTitude not connected, can't close");

    }
}

- (void)stop
{
    self.state = state_exit;
}



#pragma mark - MQtt Callback methods


- (void)session:(MQTTSession*)sender handleEvent:(MQTTSessionEvent)eventCode {
    switch (eventCode) {
        case MQTTSessionEventConnected:
            self.state = state_connected;
            break;
        case MQTTSessionEventConnectionRefused:
            self.state = state_error;
            self.state = state_waiting;
            break;
        case MQTTSessionEventConnectionClosed:
            self.state = state_waiting;
            break;
        case MQTTSessionEventProtocolError:
            break;
        case MQTTSessionEventConnectionError:
        {
            if (self.state != state_closing) {
                self.state = state_error;
                if (self.reconnectTime < RECONNECT_TIMER_MAX) {
                    self.reconnectTime *= 2;
                }
                NSLog(@"reconnect after: %f", self.reconnectTime);

                self.reconnectTimer = [NSTimer timerWithTimeInterval:self.reconnectTime
                                                              target:self
                                                            selector:@selector(reconnect)
                                                            userInfo:Nil repeats:FALSE];
                NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
                [runLoop addTimer:self.reconnectTimer
                          forMode:NSDefaultRunLoopMode];
            }
            
            break;
        }
        default:
            NSLog(@"MQTTitude unknown eventCode: %d", eventCode);
            self.state = state_exit;
            break;
    }
}

/*
 * Incoming Data Handler for subscriptions
 *
 * all incoming data is responded to by a publish of the current position
 *
 */

- (void)session:(MQTTSession *)session newMessage:(NSData *)data onTopic:(NSString *)topic
{
    
    NSLog(@"Received %@ %@", topic, [self dataToString:data]);

    if (self.inactivityTimer) {
        [self.inactivityTimer invalidate];
    }
    
    NSDictionary *dictionary = @{@"TOPIC": topic,
                                 @"DATA": data
                                 };
    [(NSObject *)self.delegate performSelector:@selector(handleMessage:)
                          onThread:[NSThread mainThread]
                        withObject:dictionary
                     waitUntilDone:NO];

}

- (void)showIndicator
{
    NSInteger indicator;
    
    switch (self.state) {
        case state_connected:
            indicator = indicator_green;
            break;
        case state_error:
            indicator = indicator_red;
            break;
        case state_connecting:
        case state_closing:
            indicator = indicator_amber;
            break;
        case state_waiting:
        case state_exit:
        default:
            indicator = indicator_idle;
            break;
    }
    
    [(NSObject *)self.delegate performSelector:@selector(showIndicator:)
                          onThread:[NSThread mainThread]
                        withObject:@(indicator)
                     waitUntilDone:NO];
}



- (void)sendData:(NSDictionary *)parameters
{
    if (self.state != state_connected) {
        NSLog(@"into fifo");
        [self.fifo addObject:parameters];
        [self connectToInternal];
    } else {
        [self sendData:parameters[@"DATA"]
                 topic:parameters[@"TOPIC"]
                   qos:[parameters[@"QOS"] intValue]
            retainFlag:[parameters[@"RETAINFLAG"] boolValue]];
    }
}

- (void)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retainFlag:(BOOL)retainFlag
{
    self.topic = topic;
    self.qos = qos;
    self.retainFlag = retainFlag;
    
    NSLog(@"Sending: %@", [self dataToString:data]);
    
    if (self.inactivityTimer) {
        [self.inactivityTimer invalidate];
    }
    
    switch (qos) {
        case 0:
            [self.session publishDataAtMostOnce:data onTopic:[NSString stringWithFormat:@"%@", topic] retain:retainFlag];
            break;
        case 1:
            [self.session publishDataAtLeastOnce:data onTopic:[NSString stringWithFormat:@"%@", topic] retain:retainFlag];
            break;
        case 2:
            [self.session publishDataExactlyOnce:data onTopic:[NSString stringWithFormat:@"%@", topic] retain:retainFlag];
            break;
        default:
            NSLog(@"MQTTitude unknown qos: %d", qos);
            break;
    }
}

- (NSString *)dataToString:(NSData *)data
{
    /* the following lines are necessary to convert data which is possibly not null-terminated into a string */
    NSString *message = [[NSString alloc] init];
    for (int i = 0; i < data.length; i++) {
        char c;
        [data getBytes:&c range:NSMakeRange(i, 1)];
        message = [message stringByAppendingFormat:@"%c", c];
    }
    return message;
}

@end
