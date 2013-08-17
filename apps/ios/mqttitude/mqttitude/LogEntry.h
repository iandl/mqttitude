//
//  LogEntry.h
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LogEntry : NSObject
@property (strong, nonatomic) NSDate *timestamp;
@property (strong, nonatomic) NSString *message;
@end
