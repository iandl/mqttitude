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
@property (strong, nonatomic) NSTimer *timeoutTimer;
@property (strong, nonatomic) MQTTSession *session;
@property (nonatomic) BOOL background;

#define STATE_INITIAL 0
#define STATE_WAITING 1
#define STATE_CONNECTING 2
#define STATE_CONNECTED 3
#define STATE_CONNECTION_ERROR 4
#define STATE_CLOSED 5
#define STATE_REFUSED 6
#define STATE_PROTOCOL_ERROR 7
#define STATE_EXIT 9

@property (nonatomic) NSInteger state;

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

#define STATE_INITIAL 0
#define STATE_WAITING 1
#define STATE_CONNECTING 2
#define STATE_CONNECTED 3
#define STATE_CONNECTION_ERROR 4
#define STATE_CLOSED 5
#define STATE_REFUSED 6
#define STATE_PROTOCOL_ERROR 7
#define STATE_CLOSING 8
#define STATE_EXIT 9

#define RECONNECT_SLEEP 5.0
#define WAIT_SLEEP 15.0

- (void)main
{
    self.state = STATE_INITIAL;
    
    do
    {
        NSLog(@"Connection thread state:%d", self.state);
        [self showIndicator];

        switch (self.state) {
            case STATE_INITIAL:
                self.state = STATE_WAITING;
                break;
            case STATE_WAITING:
            {
                if ([NSThread currentThread].isCancelled) {
                    self.state = STATE_EXIT;
                }
                break;
            }
            case STATE_CONNECTING:
                break;
            case STATE_CONNECTED:
                if ([NSThread currentThread].isCancelled) {
                    [self disconnect];
                }
                if (!self.timeoutTimer || !self.timeoutTimer.isValid) {
                    self.timeoutTimer = [NSTimer timerWithTimeInterval:WAIT_SLEEP target:self selector:@selector(timeout) userInfo:Nil repeats:FALSE];
                    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
                    [runLoop addTimer:self.timeoutTimer forMode:NSDefaultRunLoopMode];
                }
                break;
            case STATE_PROTOCOL_ERROR:
            case STATE_CONNECTION_ERROR:
            {
                if ([NSThread currentThread].isCancelled) {
                    self.state = STATE_EXIT;
                    break;
                }

                self.state = STATE_WAITING;
                self.reconnectTimer = [NSTimer timerWithTimeInterval:RECONNECT_SLEEP target:self selector:@selector(reconnect) userInfo:Nil repeats:FALSE];
                NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
                [runLoop addTimer:self.reconnectTimer forMode:NSDefaultRunLoopMode];
                break;
            }
            case STATE_CLOSED:
                self.state = STATE_EXIT;
                break;
            case STATE_REFUSED:
                self.state = STATE_EXIT;
                break;
            case STATE_EXIT:
            default:
                break;
        }
        
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    while (self.state != STATE_EXIT);
}

- (void)reconnect
{
    self.reconnectTimer = nil;
    [self sessionMessage:NSLocalizedString(@"reconnect",
                                           @"Status messsage to the user MQTT reconnect")];
    [self connectTo:self.host port:self.port tls:self.tls auth:self.auth user:self.user pass:self.pass topic:self.willTopic message:self.willMessage];
}

- (void)timeout
{
    self.timeoutTimer = nil;
    [self sessionMessage:NSLocalizedString(@"timeout",
                                           @"Status messsage to the user MQTT inactivity timeout")];
    [self disconnect];
}


#define LISTENTO @"listento"
#define OTHERS @"dt27/#"
#define MQTT_KEEPALIVE 10

- (void)connectTo:(NSDictionary *)parameters
{
    self.background = [parameters[@"BACKGROUND"] boolValue];

    [self connectTo:parameters[@"HOST"]
               port:[parameters[@"PORT"] intValue]
                tls:[parameters[@"TLS"] boolValue]
                auth:[parameters[@"AUTH"] boolValue]
               user:parameters[@"USER"]
               pass:parameters[@"PASS"]
              topic:parameters[@"TOPIC"]
            message:parameters[@"DATA"]];
}

- (void)connectTo:(NSString *)host port:(NSInteger)port tls:(BOOL)tls auth:(BOOL)auth user:(NSString *)user pass:(NSString *)pass topic:(NSString *)topic message:(NSData *)message;
{
    self.host = host;
    self.port = port;
    self.tls = tls;
    self.auth = auth;
    self.user = user;
    self.pass = pass;
    self.willTopic = topic;
    self.willMessage = message;
    
    if (self.state == STATE_WAITING) {
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
        
        [self.session setDelegate:self];
        self.state = STATE_CONNECTING;
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
    if (self.state == STATE_CONNECTED) {
        self.state = STATE_CLOSING;
        [self.session unsubscribeTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]];
        [self.session unsubscribeTopic:[NSString stringWithFormat:OTHERS]];
        [self.session close];
    } else {
        self.state = STATE_CLOSED;
        NSLog(@"MQTTitude not connected, can't close");

    }
}

#pragma mark - MQtt Callback methods


- (void)session:(MQTTSession*)sender handleEvent:(MQTTSessionEvent)eventCode {
    switch (eventCode) {
        case MQTTSessionEventConnected:
            [self sessionMessage: NSLocalizedString(@"connected",
                                                    @"Status messsage to the user MQTT is connected to host")];
            self.state = STATE_CONNECTED;
            break;
        case MQTTSessionEventConnectionRefused:
            [self sessionMessage: NSLocalizedString(@"refused",
                                                    @"Status messsage to the user MQTT connect to host was refused")];
            self.state = STATE_REFUSED;
            break;
        case MQTTSessionEventConnectionClosed:
            [self sessionMessage: NSLocalizedString(@"closed",
                                                    @"Status messsage to the user MQTT connection to host was closed")];
            self.state = STATE_CLOSED;
            break;
        case MQTTSessionEventConnectionError:
        {
            [self sessionMessage:NSLocalizedString(@"connection error",
                                                   @"Status messsage to the user MQTT connection problem")];
            self.state = STATE_CONNECTION_ERROR;
            break;
        }
        case MQTTSessionEventProtocolError:
            [self sessionMessage:NSLocalizedString(@"protocol error",
                                                   @"Status messsage to the user MQTT detected a protocol error")];
            self.state = STATE_PROTOCOL_ERROR;
            break;
        default:
            [self sessionMessage:[NSString stringWithFormat:@"MQTTitude unknown eventCode: %d", eventCode]];
            self.state = STATE_EXIT;
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
    NSLog(@"Received Data %@: %@", topic, [self dataToString:data]);
    if (self.timeoutTimer) {
        [self.timeoutTimer invalidate];
    }
    
    if (self.background) {
        if ([topic isEqualToString:self.topic]) {
            // receiving own data
        } else if ([topic isEqualToString:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]]) {
            [self.controller performSelector:@selector(publishNow) onThread:[NSThread mainThread] withObject:Nil waitUntilDone:NO];
            
        } else {
            NSError *error;
            NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (dictionary) {
                if ([dictionary[@"_type"] isEqualToString:@"location"]) {
                    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([dictionary[@"lat"] floatValue], [dictionary[@"lon"] floatValue]);
                    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                         altitude:[dictionary[@"alt"] floatValue]
                                                               horizontalAccuracy:[dictionary[@"acc"] floatValue]
                                                                 verticalAccuracy:[dictionary[@"vac"] floatValue]
                                                                        timestamp:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] floatValue]]];
                    NSDictionary *dictionary = @{@"LOCATION": location, @"TOPIC": topic};
                    [self.controller performSelector:@selector(locationToMap:) onThread:[NSThread mainThread] withObject:dictionary waitUntilDone:NO];
                }
            }
        }
    }
}

- (void)showIndicator
{
    NSInteger indicator = INDICATOR_IDLE;
    
    switch (self.state) {
        case STATE_CONNECTED:
            indicator = INDICATOR_GREEN;
            break;
        case STATE_CONNECTION_ERROR:
        case STATE_PROTOCOL_ERROR:
        case STATE_REFUSED:
            indicator = INDICATOR_RED;
            break;
        case STATE_CONNECTING:
        case STATE_INITIAL:
        case STATE_WAITING:
        case STATE_CLOSING:
            indicator = INDICATOR_YELLOW;
            break;
        case STATE_CLOSED:
        case STATE_EXIT:
        default:
            indicator = INDICATOR_IDLE;
            break;
    }

[self.controller performSelector:@selector(showIndicator:)
                        onThread:[NSThread mainThread]
                      withObject:@(indicator)
                   waitUntilDone:NO];
}

- (void)sessionMessage:(NSString *)message
{
    NSString *sessionMessage = [NSString stringWithFormat:@"%@ %@%@ :%d %@",
                                message,
                                (self.auth) ? [NSString stringWithFormat:@"%@@ ", self.user] : @"",
                                self.host,
                                (unsigned int)self.port,
                                (self.tls) ? @"TLS" : @"PLAIN"
                                ];
    

    [self.controller performSelector:@selector(showStatus:)
                            onThread:[NSThread mainThread]
                          withObject:sessionMessage
                       waitUntilDone:NO];
    
    [self.controller performSelector:@selector(log:) onThread:[NSThread mainThread] withObject:sessionMessage waitUntilDone:NO];
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

- (void)sendData:(NSDictionary *)parameters
{
    [self sendData:parameters[@"DATA"]
             topic:parameters[@"TOPIC"]
               qos:[parameters[@"QOS"] intValue]
        retainFlag:[parameters[@"RETAINFLAG"] boolValue]];
}

- (void)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retainFlag:(BOOL)retainFlag 
{
    self.topic = topic;
    self.qos = qos;
    self.retainFlag = retainFlag;
    
    if (self.timeoutTimer) {
        [self.timeoutTimer invalidate];
    }
 
    if ((self.state == STATE_CONNECTED) || (self.state == STATE_CONNECTING)) {
        NSString *message = [self dataToString:data];
        [self.controller performSelector:@selector(log:) onThread:[NSThread mainThread] withObject:message waitUntilDone:NO];
        
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
    } else {
        NSLog(@"MQTTitude not connected, can't send");
    }
}


@end
