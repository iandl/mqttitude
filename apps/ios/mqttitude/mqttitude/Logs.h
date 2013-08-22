//
//  Logs.h
//  mqttitude
//
//  Created by Christoph Krey on 20.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LogEntry.h"

@interface Logs : NSObject
- (void)log:(NSString *)message;
- (LogEntry *)elementAtPosition:(NSInteger)pos;
- (NSInteger)count;
@end
