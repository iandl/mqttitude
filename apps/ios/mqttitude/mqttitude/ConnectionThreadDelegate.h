//
//  ConnectionThreadDelegate.h
//  mqttitude
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>

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
