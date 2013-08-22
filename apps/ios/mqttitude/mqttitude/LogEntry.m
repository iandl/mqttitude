//
//  LogEntry.m
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "LogEntry.h"

@implementation LogEntry
+ (id)initWithMessage:(NSString *)message at:(NSDate *)timestamp
{
    LogEntry *logEntry = [[LogEntry alloc] init];
    
    logEntry.message = message;
    logEntry.timestamp = timestamp;
    
    return logEntry;
}
@end
