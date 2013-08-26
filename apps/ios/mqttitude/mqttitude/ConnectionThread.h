//
//  ConnectionThread.h
//  mqttitude
//
//  Created by Christoph Krey on 20.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MQTTSession.h"
#import "ConnectionThreadDelegate.h"

@interface ConnectionThread : NSThread
@property (weak, nonatomic) id<ConnectionThreadDelegate> delegate;

- (void)connectTo:(NSDictionary *)parameters;
- (void)sendData:(NSDictionary *)parameters;
- (void)disconnect;
- (void)stop;

@end
