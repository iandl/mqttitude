//
//  Connection.h
//  mqttitude
//
//  Created by Christoph Krey on 25.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionThreadDelegate.h"

@interface Connection : NSObject
@property (weak, nonatomic) id<ConnectionThreadDelegate> delegate;
- (void)connectTo:(NSString *)host port:(NSInteger)port tls:(BOOL)tls auth:(BOOL)auth user:(NSString *)user pass:(NSString *)pass willTopic:(NSString *)willTopic will:(NSData *)will;
- (void)sendData:(NSData *)data topic:(NSString *)topic qos:(NSInteger)qos retain:(BOOL)retainFlag;
- (void)disconnect;
- (void)stop;

@end
