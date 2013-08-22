//
//  ConnectionThread.m
//  mqttitude
//
//  Created by Christoph Krey on 20.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "ConnectionThread.h"

@interface ConnectionThread()
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) MQTTSession *session;

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
@property (nonatomic) BOOL background;
@end

@implementation ConnectionThread

- (void)main
{
    do
    {
        NSLog(@"while(1)");
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate distantFuture]];
    }
    while (1);

}

#define LISTENTO @"listento"
#define MQTT_KEEPALIVE 60

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
    [self.timer invalidate];
 
    self.host = host;
    self.port = port;
    self.tls = tls;
    self.auth = auth;
    self.user = user;
    self.pass = pass;
    self.willTopic = topic;
    self.willMessage = message;
    
    if (!self.session) {
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
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
        [self.session subscribeTopic:[NSString stringWithFormat:@"%@/%@", self.willTopic, LISTENTO]];
    }
}

- (void)disconnect
{
    [self.timer invalidate];
    if (self.session) {
        [self.session unsubscribeTopic:[NSString stringWithFormat:@"%@/%@", self.willTopic, LISTENTO]];
        [self.session close];
        self.session = nil;
    }
}

#pragma mark - MQtt Callback methods
#define RECONNECT_SLEEP 10.0


- (void)session:(MQTTSession*)sender handleEvent:(MQTTSessionEvent)eventCode {
    switch (eventCode) {
        case MQTTSessionEventConnected:
            [self sessionMessage: NSLocalizedString(@"connected",
                                                    @"Status messsage to the user MQTT is connected to host")];
            break;
        case MQTTSessionEventConnectionRefused:
            [self sessionMessage: NSLocalizedString(@"refused",
                                                    @"Status messsage to the user MQTT connect to host was refused")];
            [self disconnect];
            break;
        case MQTTSessionEventConnectionClosed:
            [self sessionMessage: NSLocalizedString(@"closed",
                                                    @"Status messsage to the user MQTT connection to host was closed")];
            break;
        case MQTTSessionEventConnectionError:
        {
            [self sessionMessage:NSLocalizedString(@"connection error",
                                                   @"Status messsage to the user MQTT connection problem")];
            //Forcing reconnection
            [self.timer invalidate];
            self.session = nil;
            self.timer = [NSTimer timerWithTimeInterval:RECONNECT_SLEEP target:self selector:@selector(reconnect) userInfo:Nil repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
            [runLoop addTimer:self.timer forMode:NSDefaultRunLoopMode];
            break;
        }
        case MQTTSessionEventProtocolError:
            [self sessionMessage:NSLocalizedString(@"protocol error",
                                                   @"Status messsage to the user MQTT detected a protocol error")];
            break;
        default:
            [self sessionMessage:[NSString stringWithFormat:@"MQTTitude unknown eventCode: %d", eventCode]];
            break;
    }
}


- (void)reconnect
{
    self.timer = nil;
    [self sessionMessage:NSLocalizedString(@"reconnect",
                                           @"Status messsage to the user MQTT reconnect")];
    [self connectTo:self.host port:self.port tls:self.tls auth:self.auth user:self.user pass:self.pass topic:self.topic message:self.willMessage];
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
    
    if (self.background) {
        [self.controller performSelector:@selector(publishNow) onThread:[NSThread mainThread] withObject:Nil waitUntilDone:NO];
    }
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
    
    NSString *message = [self dataToString:data];
    [self.controller performSelector:@selector(log:) onThread:[NSThread mainThread] withObject:message waitUntilDone:NO];
    
    if (self.session) {
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
        NSLog(@"MQTTitude no session");
    }
}


@end
