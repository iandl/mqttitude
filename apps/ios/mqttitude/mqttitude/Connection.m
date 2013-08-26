//
//  Connection.m
//  mqttitude
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Connection.h"
#include "ConnectionThread.h"

@interface Connection()
@property (strong, nonatomic) ConnectionThread *connectionThread;
@property (strong, nonatomic) NSTimer *tickler;
@end

@implementation Connection
#define TICKLER 60*60 //every hour

- (id)init
{
    self = [super init];

    return self;
}

- (void)setDelegate:(NSObject<ConnectionThreadDelegate> *)delegate
{
    _delegate = delegate;
    if (self.connectionThread) {
        [self.connectionThread performSelector:@selector(setDelegate:) onThread:self.connectionThread withObject:self.delegate waitUntilDone:YES];
    }
}

- (ConnectionThread *)connectionThread
{
    if (!_connectionThread) {
        _connectionThread = [[ConnectionThread alloc] init];
        [self.connectionThread setStackSize:4096*128]; // 1024k
        [self.connectionThread start];
        [self.connectionThread performSelector:@selector(setDelegate:) onThread:self.connectionThread withObject:self.delegate waitUntilDone:YES];
    }
    return _connectionThread;
}

- (void)connectTo:(NSString *)host port:(NSInteger)port tls:(BOOL)tls auth:(BOOL)auth user:(NSString *)user pass:(NSString *)pass willTopic:(NSString *)willTopic will:(NSData *)will
{
    NSDictionary *parameters = @{@"HOST": host,
                                 @"PORT": [NSString stringWithFormat:@"%d", (unsigned int)port],
                                 @"TLS": [NSString stringWithFormat:@"%d", tls],
                                 @"AUTH": [NSString stringWithFormat:@"%d", auth],
                                 @"USER": user,
                                 @"PASS": pass,
                                 @"TOPIC": willTopic,
                                 @"DATA": will,
                                 };
    
    [self.connectionThread performSelector:@selector(connectTo:) onThread:self.connectionThread withObject:parameters waitUntilDone:YES];
}

- (void)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag
{
    NSDictionary *parameters = @{@"DATA": data,
                                 @"TOPIC": topic,
                                 @"QOS": [NSString stringWithFormat:@"%d", qos],
                                 @"RETAINFLAG": [NSString stringWithFormat:@"%d", retainFlag]
                                 };
    [self.connectionThread performSelector:@selector(sendData:) onThread:self.connectionThread withObject:parameters waitUntilDone:YES];
}

- (void)disconnect
{
    [self.connectionThread performSelector:@selector(disconnect) onThread:self.connectionThread withObject:nil waitUntilDone:YES];
}

- (void)stop
{
    [self.connectionThread performSelector:@selector(stop) onThread:self.connectionThread withObject:nil waitUntilDone:YES];
}


@end
