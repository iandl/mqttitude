//
//  LongitudeSettingsTVCViewController.h
//  Longitude
//
//  Created by Christoph Krey on 15.07.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface mqttitudeSettingsTVCViewController : UITableViewController 
@property (strong, nonatomic) NSString *host;
@property (nonatomic) UInt32 port;
@property (nonatomic) BOOL tls;
@property (nonatomic) BOOL auth;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *pass;
@property (strong, nonatomic) NSString *topic;
@property (nonatomic) BOOL retainFlag  ;
@property (nonatomic) NSInteger qos;

@end
