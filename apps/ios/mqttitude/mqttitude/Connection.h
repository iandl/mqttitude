//
//  Connection.h
//  mqttitude
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MQTTSession.h"


@protocol ConnectionDelegate <NSObject>
#define LISTENTO @"listento"

enum indicator {
    indicator_idle = 0,
    indicator_green = 1,
    indicator_amber = 2,
    indicator_red = 3
};

- (void)showIndicator:(NSInteger)indicator;
- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic;
@end

@interface Connection: NSObject <MQTTSessionDelegate>
@property (weak, nonatomic) id<ConnectionDelegate> delegate;

- (void)connectTo:(NSString *)host port:(NSInteger)port tls:(BOOL)tls auth:(BOOL)auth user:(NSString *)user pass:(NSString *)pass willTopic:(NSString *)willTopic will:(NSData *)will;
- (void)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag;
- (void)disconnect;
- (void)stop;

@end
