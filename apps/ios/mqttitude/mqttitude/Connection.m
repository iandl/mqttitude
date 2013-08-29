//
//  Connection.m
//  mqttitude
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Connection.h"

@interface Connection()
@property (strong, nonatomic) NSTimer *reconnectTimer;
@property (nonatomic) float reconnectTime;
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

enum state {
    state_starting,
    state_connecting,
    state_error,
    state_connected,
    state_closing,
    state_exit
};

#define RECONNECT_TIMER 1.0
#define RECONNECT_TIMER_MAX 300.0

#define DEBUGGING

@implementation Connection

- (id)init
{
    self = [super init];
    self.state = state_starting;
    return self;
}

- (void)setState:(NSInteger)state
{
    _state = state;
#ifdef DEBUGGING
    NSLog(@"Connection thread state:%d", self.state);
#endif
    [self showIndicator];
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
        case state_starting:
        case state_exit:
        default:
            indicator = indicator_idle;
            break;
    }
    
    [self.delegate showIndicator:indicator];
}


- (NSArray *)fifo
{
    if (!_fifo)
        _fifo = [[NSMutableArray alloc] init];
    return _fifo;
}


- (void)reconnect
{
#ifdef DEBUGGING
    NSLog(@"reconnect");
#endif
    self.reconnectTimer = nil;
    if (self.reconnectTime < RECONNECT_TIMER_MAX) {
        self.reconnectTime *= 2;
    }
    self.state = state_starting;
    
    [self connectToInternal];
}

/*
 * externally visible methods
 */

#define OTHERS @"#"
#define MQTT_KEEPALIVE 60

- (void)connectTo:(NSString *)host port:(NSInteger)port tls:(BOOL)tls auth:(BOOL)auth user:(NSString *)user pass:(NSString *)pass willTopic:(NSString *)willTopic will:(NSData *)will
{
    self.host = host;
    self.port = port;
    self.tls = tls;
    self.auth = auth;
    self.user = user;
    self.pass = pass;
    self.willTopic = willTopic;
    self.topic = willTopic;
    self.willMessage = will;
    
    self.reconnectTime = RECONNECT_TIMER;
    
    [self connectToInternal];
}

- (void)connectToInternal
{
    if (self.state == state_starting) {
        self.state = state_connecting;
        NSString *clientId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        
        self.session = [[MQTTSession alloc] initWithClientId:clientId userName:self.auth ? self.user : @"" password:self.auth ? self.pass : @"" keepAlive:MQTT_KEEPALIVE cleanSession:YES
                                                   willTopic:self.willTopic willMsg:self.willMessage willQoS:1 willRetainFlag:YES runLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.session setDelegate:self];
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
        [self.session subscribeToTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO] atLevel:1];
        [self.session subscribeToTopic:[NSString stringWithFormat:OTHERS] atLevel:1];
    } else {
        NSLog(@"MQTTitude not starting, can't connect");
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
        self.state = state_starting;
        NSLog(@"MQTTitude not connected, can't close");
        
    }
}

- (void)stop
{
    [self disconnect];
    self.state = state_exit;
}



#pragma mark - MQtt Callback methods


- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode
{
#ifdef DEBUGGING
    NSLog(@"MQTTitude eventCode: %d", eventCode);
#endif
    [self.reconnectTimer invalidate];
    switch (eventCode) {
        case MQTTSessionEventConnected:
            self.state = state_connected;
            while ([self.fifo count]) {
                /*
                 * if there are some queued send messages, send them
                 */
                NSDictionary *parameters = self.fifo[0];
                [self.fifo removeObjectAtIndex:0];
                [self sendData:parameters[@"DATA"] topic:parameters[@"TOPIC"] qos:[parameters[@"QOS"] intValue] retain:[parameters[@"RETAINFLAG"] boolValue]];
            }
            break;
            self.state = state_error;
            break;
        case MQTTSessionEventConnectionClosed:
            self.state = state_starting;
            break;
        case MQTTSessionEventProtocolError:
        case MQTTSessionEventConnectionRefused:
        case MQTTSessionEventConnectionError:
        {
#ifdef DEBUGGING
            NSLog(@"reconnect after: %f", self.reconnectTime);
#endif
            self.reconnectTimer = [NSTimer timerWithTimeInterval:self.reconnectTime
                                                          target:self
                                                        selector:@selector(reconnect)
                                                        userInfo:Nil repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.reconnectTimer
                      forMode:NSDefaultRunLoopMode];
            
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

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic
{
#ifdef DEBUGGING
    NSLog(@"Received %@ %@", topic, [self dataToString:data]);
#endif
    [self.delegate handleMessage:data onTopic:topic];
}


- (void)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag
{
    self.topic = topic;
    self.qos = qos;
    self.retainFlag = retainFlag;
    
    if (self.state != state_connected) {
#ifdef DEBUGGING
        NSLog(@"into fifo");
#endif
        NSDictionary *parameters = @{
                                     @"DATA": data,
                                     @"TOPIC": topic,
                                     @"QOS": [NSString stringWithFormat:@"%d",  qos],
                                     @"RETAINFLAG": [NSString stringWithFormat:@"%d",  retainFlag]
                                     };
        [self.fifo addObject:parameters];
        [self connectToInternal];
    } else {
#ifdef DEBUGGING
        NSLog(@"Sending: %@", [self dataToString:data]);
#endif
        [self.session publishData:data onTopic:topic retain:retainFlag qos:qos];
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
