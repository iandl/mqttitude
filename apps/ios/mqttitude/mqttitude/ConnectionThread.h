//
//  ConnectionThread.h
//  mqttitude
//
//  Created by Christoph Krey on 20.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MQTTSession.h"
#import "mqttitudeViewController.h"

@interface ConnectionThread : NSThread
@property (weak, nonatomic) mqttitudeViewController *controller;

- (void)connectTo:(NSDictionary *)parameters;
- (void)disconnect;
- (void)sendData:(NSDictionary *)parameters;

@end
