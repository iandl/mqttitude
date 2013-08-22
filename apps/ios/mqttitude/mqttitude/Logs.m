//
//  Logs.m
//  mqttitude
//
//  Created by Christoph Krey on 20.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Logs.h"

@interface Logs()
@property (strong, nonatomic) NSMutableArray *logArray;
@end

@implementation Logs

- (NSString *)description
{
    NSString *string = [[NSString alloc] init];

    for (LogEntry *logEntry in self.logArray) {
        string = [string stringByAppendingFormat:@"%@:%@\n", logEntry.timestamp, logEntry.message];
    };
    return string;
}

- (NSMutableArray *)logArray
{
    if (!_logArray) _logArray = [[NSMutableArray alloc] init];
    return _logArray;
}

- (LogEntry *)elementAtPosition:(NSInteger)pos
{
    if (pos > [self count]) {
        return nil;
    } else {
        return self.logArray[pos];
    }
}

#define MAX_LOGS 50

- (void)log:(NSString *)message
{
    NSLog(@"%@", message);
    
    LogEntry *logEntry = [[LogEntry alloc] init];
    logEntry.timestamp = [NSDate date];
    logEntry.message = message;
    
    [self.logArray insertObject:logEntry atIndex:0];
    if ([self.logArray count] > MAX_LOGS) {
        [self.logArray removeLastObject];
    }
}

- (NSInteger)count
{
    return [self.logArray count];
}
@end
