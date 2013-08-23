//
//  mqttitudeViewController.h
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "MQTTSession.h"

#define INDICATOR_RED 3
#define INDICATOR_YELLOW 2
#define INDICATOR_GREEN 1
#define INDICATOR_IDLE 0

@interface mqttitudeViewController : UIViewController <CLLocationManagerDelegate, MKMapViewDelegate>
- (void)showStatus:(NSString *)status;
- (void)showIndicator:(NSNumber *)indicator;
- (void)publishNow;
- (void)log:(NSString *)message;
- (void)locationToMap:(NSDictionary *)dictionary;

@end
