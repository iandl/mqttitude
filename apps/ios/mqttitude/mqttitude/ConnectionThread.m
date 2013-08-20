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
@property (strong, nonatomic) NSData *message;
@property (nonatomic) BOOL tls;
@property (nonatomic) BOOL auth;
@property (nonatomic) NSInteger port;
@end

@implementation ConnectionThread

- (void)main
{
    //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    
    //[pool release];  // Release the objects in the pool.
}

#define LISTENTO @"LISTENTO"
#define MQTT_KEEPALIVE 60

- (void)connectTo:(NSString *)host port:(NSInteger)port tls:(BOOL)tls auth:(BOOL)auth user:(NSString *)user pass:(NSString *)pass topic:(NSString *)topic message:(NSData *)message;
{
    [self.timer invalidate];
 
    self.host = host;
    self.port = port;
    self.tls = tls;
    self.auth = auth;
    self.user = user;
    self.pass = pass;
    self.topic = topic;
    self.message = message;
    
    if (!self.session) {
        NSString *clientId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        
        self.session = [[MQTTSession alloc] initWithClientId:clientId
                                                    userName:self.auth ? self.user : @""
                                                    password:self.auth ? self.pass : @""
                                                   keepAlive:MQTT_KEEPALIVE
                                                cleanSession:YES
                                                   willTopic:self.topic
                                                     willMsg:self.message
                                                     willQoS:1
                                              willRetainFlag:YES];
        
        [self.session setDelegate:self];
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
        [self.session subscribeTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]];
    }
}

- (void)disconnect
{
    [self.timer invalidate];
    if (self.session) {
        [self.session unsubscribeTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]];
        [self.session close];
        self.session = nil;
    }
}


@end
