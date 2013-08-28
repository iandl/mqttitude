//
//  ConnectionThread.h
//  mqttitude
//
//  Created by Christoph Krey on 20.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MQTTSession.h"


@protocol ConnectionThreadDelegate <NSObject>
#define LISTENTO @"listento"

enum indicator {
    indicator_idle = 0,
    indicator_green = 1,
    indicator_amber = 2,
    indicator_red = 3
};

- (void)showIndicator:(NSNumber *)indicator;
- (void)handleMessage:(NSDictionary *)dictionary;

@end

@interface ConnectionThread : NSThread <MQTTSessionDelegate>
@property (weak, nonatomic) id<ConnectionThreadDelegate> delegate;

- (void)connectTo:(NSDictionary *)parameters;
- (void)sendData:(NSDictionary *)parameters;
- (void)disconnect;
- (void)stop;

@end
