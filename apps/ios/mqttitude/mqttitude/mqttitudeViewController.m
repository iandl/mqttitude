//
//  mqttitudeViewController.m
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "mqttitudeViewController.h"
#import "mqttitudeSettingsTVCViewController.h"
#import "mqttitudeLogTVCViewController.h"
#import "Annotation.h"
#import "Logs.h"
#import "Connection.h"
#import "mqttitudeIndicatorView.h"

@interface mqttitudeViewController ()
@property (strong, nonatomic) MQTTSession *session;
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) Logs *logs;
@property (strong, nonatomic) NSTimer *keepAliveTimer;

@property (strong, nonatomic) NSString *topic;
@property (nonatomic) BOOL retainFlag;
@property (nonatomic) NSInteger qos;
@property (nonatomic) BOOL background;

@property (strong, nonatomic) NSString *host;
@property (nonatomic) UInt32 port;
@property (nonatomic) BOOL tls;
@property (nonatomic) BOOL auth;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *pass;

@property (strong, nonatomic) NSMutableArray *annotationArray;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet mqttitudeIndicatorView *indicatorView;
@property (weak, nonatomic) IBOutlet MKUserTrackingBarButtonItem *trackingButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stopButton;

@property (strong, nonatomic) Connection *connection;

@end

@implementation mqttitudeViewController

#define DEBUGGING
#define KEEPALIVE 120.0

- (void)viewDidLoad
{
    /*
     * Initializing all Objects
     */
     
    [super viewDidLoad];

    self.logs = [[Logs alloc] init];
    
    self.connection = [[Connection alloc] init];
    self.connection.delegate = self;
    
    self.annotationArray = [[NSMutableArray alloc] init];
    if ([CLLocationManager locationServicesEnabled]) {
        self.manager = [[CLLocationManager alloc] init];
        self.manager.delegate = self;
        self.mapView.delegate = self;
        self.mapView.showsUserLocation = YES;
        [self.mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
        (void)[self.trackingButton initWithMapView:self.mapView];
    } else {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        [self alert:NSLocalizedString(@"No Core Location Services", @"No Core Location Services")
            message:[NSString stringWithFormat:@"%@ %d",
                     NSLocalizedString(@"MQTTitude not authorized for CoreLocation", @"MQTTitude not authorized for CoreLocation"),
                     status]];
    }

    [self.logs log:[NSString stringWithFormat:@"%@ v%@ on %@",
                    [NSBundle mainBundle].infoDictionary[@"CFBundleName"],
                    [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"],
                    [[[UIDevice currentDevice] identifierForVendor] UUIDString]]];

    [self settingsFromPropertyList];
    [self connect];
    
    [self.manager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
    [self.manager startMonitoringSignificantLocationChanges];
    
    self.keepAliveTimer = [NSTimer timerWithTimeInterval:KEEPALIVE target:self selector:@selector(keepAlive:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.keepAliveTimer forMode:NSRunLoopCommonModes];
    

#ifdef DEBUGGING
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
#endif
}

- (void)connect
{
    NSDictionary *will = @{
                           @"tst": [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]],
                           @"_type": [NSString stringWithFormat:@"%@", @"lwt"]
                           };

    [self.connection connectTo:self.host
                          port:self.port
                           tls:self.tls
                          auth:self.auth
                          user:self.user
                          pass:self.pass
                     willTopic:self.topic
                          will:[self jsonToData:will]];
}

#define MAX_ANNOTATIONS 50

- (void)locationToMap:(CLLocation *)location topic:(NSString *)topic
{
    // prepare annotation
    Annotation *annotation = [[Annotation alloc] init];
    annotation.coordinate = location.coordinate;
    annotation.timeStamp = location.timestamp;
    annotation.topic = topic;
    
    // if other's location, delete previous
    if (![annotation.topic isEqualToString:self.topic]) {
        for (Annotation *theAnnotation in self.annotationArray) {
            if ([theAnnotation.topic isEqualToString:annotation.topic]) {
                [self.annotationArray removeObject:theAnnotation];
                [self.mapView removeAnnotation:theAnnotation];
                break;
            }
        }
    }
    
    // add the new annotation to the map, for reference and to the log
    [self.mapView addAnnotation:annotation];
    [self.annotationArray addObject:annotation];
    [self.logs log:[NSString stringWithFormat:@"%@@%@", annotation.topic, [annotation subtitle]]];
    
    // limit the total number of annotations
    if ([self.annotationArray count] > MAX_ANNOTATIONS) {
        [self.mapView removeAnnotation:self.annotationArray[0]];
        [self.annotationArray removeObjectAtIndex:0];
    }
    
    // count other's annotation
    NSInteger others = 0;
    for (Annotation *theAnnotation in self.annotationArray) {
        if (![theAnnotation.topic isEqualToString:self.topic]) {
            others++;
        }
    }
    
    // show the user how many others are on the map
    [UIApplication sharedApplication].applicationIconBadgeNumber = others;
}

- (void)publishLocation:(CLLocation *)location
{
    [self locationToMap:location topic:self.topic];
    
    NSData *data = [self formatLocationData:location];
    
    [self.connection sendData:data topic:self.topic qos:self.qos retain:self.retainFlag];
}

- (NSData *)formatLocationData:(CLLocation *)location
{
    NSDictionary *jsonObject = @{
                                     @"lat": [NSString stringWithFormat:@"%f", location.coordinate.latitude],
                                     @"lon": [NSString stringWithFormat:@"%f", location.coordinate.longitude],
                                     @"tst": [NSString stringWithFormat:@"%.0f", [location.timestamp timeIntervalSince1970]],
                                     @"acc": [NSString stringWithFormat:@"%.0fm", location.horizontalAccuracy],
                                     @"alt": [NSString stringWithFormat:@"%f", location.altitude],
                                     @"vac": [NSString stringWithFormat:@"%.0fm", location.verticalAccuracy],
                                     @"vel": [NSString stringWithFormat:@"%f", location.speed],
                                     @"dir": [NSString stringWithFormat:@"%f", location.course],
#ifdef DEBUGGING
                        /*testing*/  @"_pow": [NSString stringWithFormat:@"%.0f", ([[UIDevice currentDevice] isBatteryMonitoringEnabled]) ? [[UIDevice currentDevice] batteryLevel] * 100.0: -1.0 ],
#endif
                                     @"_type": [NSString stringWithFormat:@"%@", @"location"]
                                     };
    return [self jsonToData:jsonObject];
}

- (NSData *)jsonToData:(NSDictionary *)jsonObject
{
    NSData *data;
    
    
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 /* not pretty printed */ error:&error];
        if (!data) {
            [self alert:NSLocalizedString(@"JSONSerialization", @"JSONSerialization")
                message:NSLocalizedString(@"Error serializing JSON object", @"Error serializing JSON object")];
            NSLog(@"Error %@ serializing JSON Object: %@", [error description], [jsonObject description]);
        }
    } else {
        [self alert:NSLocalizedString(@"JSONSerialization", @"JSONSerialization")
            message:NSLocalizedString(@"No valid JSON Object", @"No valid JSON Object")];
        NSLog(@"No valid JSON Object: %@", [jsonObject description]);
    }
    return data;
}


/* Called from LocationManager when location changes significantly
 *
 */

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
#ifdef DEBUGGING
    NSLog(@"Significant Location Change");
#endif
    for (CLLocation *location in locations) {
#ifdef DEBUGGING
        NSLog(@"Location: %@", [location description]);
#endif
        if (self.background) [self publishLocation:location];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
#ifdef DEBUGGING
    NSLog(@"locationManager didFailWithError %@", error);
#endif
    
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager
{
#ifdef DEBUGGING
    NSLog(@"locationManagerDidPauseLocationUpdates");
#endif
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager
{
#ifdef DEBUGGING
    NSLog(@"locationManagerDidResumeLocationUpdates");
#endif    
}

/* UI Actions
 *
 */

- (IBAction)publishNow:(UIBarButtonItem *)sender {
    [self publishLocation:self.manager.location];
}

- (IBAction)stop:(UIBarButtonItem *)sender {
    [self.connection stop];
    [self.manager stopMonitoringSignificantLocationChanges];
    exit(0);
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[mqttitudeSettingsTVCViewController class]]) {
        mqttitudeSettingsTVCViewController *settings = (mqttitudeSettingsTVCViewController *)segue.destinationViewController;
        settings.host = self.host;
        settings.port = self.port;
        settings.tls = self.tls;
        settings.auth = self.auth;
        settings.user = self.user;
        settings.pass = self.pass;
        settings.topic = self.topic;
        settings.retainFlag = self.retainFlag;
        settings.qos = self.qos;
        settings.background = self.background;
    } else if ([segue.destinationViewController isKindOfClass:[mqttitudeLogTVCViewController class]]) {
        mqttitudeLogTVCViewController *logs = (mqttitudeLogTVCViewController *)segue.destinationViewController;
        logs.logs = self.logs;
    } 
}

- (IBAction)settingsSaved:(UIStoryboardSegue *)seque
{
    if ([seque.sourceViewController isKindOfClass:[mqttitudeSettingsTVCViewController class]]) {
        mqttitudeSettingsTVCViewController *settings = (mqttitudeSettingsTVCViewController *)seque.sourceViewController;
        
        [self.connection disconnect];
        self.host = settings.host;
        self.port = settings.port;
        self.tls = settings.tls;
        self.auth = settings.auth;
        self.user = settings.user;
        self.pass = settings.pass;
        self.topic = settings.topic;
        self.retainFlag = settings.retainFlag;
        self.qos = settings.qos;
        self.background = settings.background;
        [self synchronizeSettings];
        [self connect];
    }
}

/* Persistent Settings
 *
 */

#define SETTINGS_KEY @"SETTINGS"

#define HOST_KEY @"HOST"
#define PORT_KEY @"PORT"
#define TLS_KEY @"TLS"
#define AUTH_KEY @"AUTH"
#define USER_KEY @"USER"
#define PASS_KEY @"PASS"

#define TOPIC_KEY @"TOPIC"
#define RETAIN_KEY @"RETAIN"
#define QOS_KEY @"QOS"
#define BACKGROUND_KEY @"BACKGROUND"

#define HOST_DEFAULT @"host"
#define PORT_DEFAULT 1883
#define TLS_DEFAULT FALSE
#define AUTH_DEFAULT FALSE
#define USER_DEFAULT @"user"
#define PASS_DEFAULT @"password"

#define TOPIC_DEFAULT @"mqttitude"
#define RETAIN_DEFAULT TRUE
#define QOS_DEFAULT 2
#define BACKGROUND_DEFAULT TRUE


- (void)synchronizeSettings
{
    [[NSUserDefaults standardUserDefaults] setObject:@{
                                            HOST_KEY:self.host,
                                            PORT_KEY:@(self.port),
                                             TLS_KEY:@(self.tls),
                                            AUTH_KEY:@(self.auth),
                                            USER_KEY:self.user,
                                            PASS_KEY:self.pass,
                                           TOPIC_KEY:self.topic,
                                          RETAIN_KEY:@(self.retainFlag),
                                             QOS_KEY:@(self.qos),
                                      BACKGROUND_KEY:@(self.background)}
                                              forKey:SETTINGS_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)settingsFromPropertyList
{
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SETTINGS_KEY];
    
    if (settings) {
        self.host = settings[HOST_KEY];
        self.port = [settings[PORT_KEY] intValue];
        self.tls = [settings[TLS_KEY] boolValue];
        self.auth = [settings[AUTH_KEY] boolValue];
        self.user = settings[USER_KEY];
        self.pass = settings[PASS_KEY];
        
        self.topic = settings[TOPIC_KEY];
        self.retainFlag = [settings[RETAIN_KEY] boolValue];
        self.qos = [settings[QOS_KEY] intValue];
        self.background = [settings[BACKGROUND_KEY] boolValue];
    } else {
        self.host = HOST_DEFAULT;
        self.port = PORT_DEFAULT;
        self.tls = TLS_DEFAULT;
        self.auth = AUTH_DEFAULT;
        self.user = USER_DEFAULT;
        self.pass = PASS_DEFAULT;
        
        self.topic = [NSString stringWithFormat:@"%@/%@", TOPIC_DEFAULT, [[UIDevice currentDevice] name]];
        self.retainFlag = RETAIN_DEFAULT;
        self.qos = QOS_DEFAULT;
        self.background = BACKGROUND_DEFAULT;
        [self synchronizeSettings];
    }
}

/* Communication from Background Thread
 *
 */

- (void)showIndicator:(NSInteger)indicator
{
    UIColor *color;
    
    switch (indicator) {
        case indicator_green:
            color = [UIColor greenColor];
            break;
        case indicator_amber:
            color = [UIColor yellowColor];
            break;
        case indicator_red:
            color = [UIColor redColor];
            break;
        case indicator_idle:
        default:
            color = [UIColor blueColor];
            break;
    }
    self.indicatorView.color = color;
    [self.indicatorView setNeedsDisplay];
}

- (void)publishNow
{
    [self publishLocation:self.manager.location];
}

- (void)log:(NSString *)message
{
    [self.logs log:message];
}

#define COMMAND_PUBLISH @"publish"

- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic
{
    if (self.background) {
        if ([topic isEqualToString:self.topic]) {
            // received own data
        } else if ([topic isEqualToString:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]]) {
            // received command
            NSString *message = [self dataToString:data];
            if ([message isEqualToString:COMMAND_PUBLISH]) {
                [self publishNow];
            } else {
                [self alert:NSLocalizedString(@"Unknown Command", @"Unknown Command")
                    message:NSLocalizedString(@"MQTTitude received an unknown command", @"MQTTitude received an unknown command")];
                NSLog(@"Unknown command: %@", message);
            }
        } else {
            // received other data
            NSError *error;
            NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (dictionary) {
                if ([dictionary[@"_type"] isEqualToString:@"location"]) {
                    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([dictionary[@"lat"] floatValue], [dictionary[@"lon"] floatValue]);
                    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                         altitude:[dictionary[@"alt"] floatValue]
                                                               horizontalAccuracy:[dictionary[@"acc"] floatValue]
                                                                 verticalAccuracy:[dictionary[@"vac"] floatValue]
                                                                        timestamp:[NSDate dateWithTimeIntervalSince1970:[dictionary[@"tst"] floatValue]]];
                    [self locationToMap:location topic:topic];
                }
            }
        }
    }
}


- (NSString *)dataToString:(NSData *)data
{
    /* the following lines are necessary to convert data which is possibly not null-terminated into a string */
    NSString *message = [[NSString alloc] init];
    for (int i = 0; i < data.length; i++) {
        char c;
        [data getBytes:&c range:NSMakeRange(i, 1)];
        message = [message stringByAppendingFormat:@"%c", c];
    }
    return message;
}


/* MapView
 *
 */
#define REUSE_ID_SELF @"MQTTitude_Annotation_self"
#define REUSE_ID_OTHER @"MQTTitude_Annotation_other"

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    } else {
        if ([annotation isKindOfClass:[Annotation class]]) {
            Annotation *MQTTannotation = (Annotation *)annotation;
            if ([MQTTannotation.topic isEqualToString:self.topic]) {
                MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_SELF];
                if (annotationView) {
                    return annotationView;
                } else {
                    MKPinAnnotationView *pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_SELF];
                    pinAnnotationView.pinColor = MKPinAnnotationColorRed;
                    pinAnnotationView.canShowCallout = YES;
                    return pinAnnotationView;
                }
            } else {
                MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_OTHER];
                if (annotationView) {
                    return annotationView;
                } else {
                    MKPinAnnotationView *pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_OTHER];
                    pinAnnotationView.pinColor = MKPinAnnotationColorGreen;
                    pinAnnotationView.canShowCallout = YES;
                    return pinAnnotationView;
                }
            }
        }
        return nil;
    }
}

- (void)keepAlive:(NSTimer *)timer
{
#ifdef DEBUGGING
    NSLog(@"%@ Alive @%.0f", [[[UIDevice currentDevice] identifierForVendor] UUIDString], [[NSDate date] timeIntervalSince1970]);
#endif
}

- (void)alert:(NSString *)title message:(NSString *)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"OK button in alert")
                                          otherButtonTitles:nil];
    [alert show];
}
@end
