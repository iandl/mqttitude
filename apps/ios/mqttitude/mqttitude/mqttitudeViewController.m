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
#import "ConnectionThread.h"
#import "mqttitudeIndicatorView.h"

@interface mqttitudeViewController ()
@property (strong, nonatomic) MQTTSession *session;
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) NSString *clientId;
@property (strong, nonatomic) NSTimer *keepalive;
@property (strong, nonatomic) Logs *logs;

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
@property (weak, nonatomic) IBOutlet UITextView *statusField;
@property (weak, nonatomic) IBOutlet mqttitudeIndicatorView *indicatorView;
@property (weak, nonatomic) IBOutlet MKUserTrackingBarButtonItem *trackingButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stopButton;

@property (strong, nonatomic) ConnectionThread *connectionThread;

@end

@implementation mqttitudeViewController



/* Setup
 *
 * Settings, Arrays, KeepAlive Timer, Location Manager
 *
 */
#define KEEP_ALIVE 60*60 //every hour

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.logs = [[Logs alloc] init];
    [self.logs log:[NSString stringWithFormat:@"%@ starting...",
                    [NSString stringWithFormat:@"%@ %@",
                     [NSBundle mainBundle].infoDictionary[@"CFBundleName"],
                     [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"]]]];
    
    /* for Testing */ [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    [self settingsFromPropertyList];
    
    self.annotationArray = [[NSMutableArray alloc] init];
    
    if ([CLLocationManager locationServicesEnabled]) {
        self.manager = [[CLLocationManager alloc] init];
        self.manager.delegate = self;
        
        self.mapView.delegate = self;
        self.mapView.showsUserLocation = YES;
        [self.mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
        (void)[self.trackingButton initWithMapView:self.mapView];
        
        [self.manager startMonitoringSignificantLocationChanges];
    } else {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        [self.logs log:[NSString stringWithFormat:@"MQTTitude not authorized for CoreLocation %d", status]];
    }
    
        
    self.keepalive = [NSTimer timerWithTimeInterval:KEEP_ALIVE target:self selector:@selector(stillhere ) userInfo:Nil repeats:TRUE];
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
    [runLoop addTimer:self.keepalive forMode:NSDefaultRunLoopMode];
    
    [self connect];
}


- (void)stillhere
{
    UIApplicationState state =  [[UIApplication sharedApplication] applicationState];
    NSLog(@"ApplicationState: %d, time remaining %10.3f",
          state,
          (state == UIApplicationStateBackground) ?
          [UIApplication sharedApplication].backgroundTimeRemaining :
            0.0);
    if ([[UIDevice currentDevice] isBatteryMonitoringEnabled]) {
        switch ([[UIDevice currentDevice] batteryState]) {
            case UIDeviceBatteryStateCharging:
                NSLog(@"Battery charging");
                break;
            case UIDeviceBatteryStateFull:
                NSLog(@"Battery full");
                break;
            case UIDeviceBatteryStateUnplugged:
                NSLog(@"Battery unplugged");
                break;
            case UIDeviceBatteryStateUnknown:
            default:
                NSLog(@"Battery state unknown");
                break;
        }
        NSLog(@"Battery level %f", [[UIDevice currentDevice] batteryLevel]);
    } else {
        NSLog(@"Battery Monitoring not enabled");
    }
    if (self.background && (!self.connectionThread || !self.connectionThread.isExecuting)) {
        [self connect];
    }
}

/* Communication to Background Thread
 *
 */

- (void)connect
{
    NSDictionary *parameters = @{@"HOST": self.host,
                                 @"PORT": [NSString stringWithFormat:@"%d", (unsigned int)self.port],
                                 @"TLS": [NSString stringWithFormat:@"%d", self.tls],
                                 @"AUTH": [NSString stringWithFormat:@"%d", self.auth],
                                 @"USER": self.user,
                                 @"PASS": self.pass,
                                 @"TOPIC": self.topic,
                                 @"DATA": [self formatLocationData:self.manager.location withType:@"lwt"],
                                 @"BACKGROUND": [NSString stringWithFormat:@"%d", self.background],
                                 };
    
    self.ConnectionThread = [[ConnectionThread alloc] init];
    self.connectionThread.controller = self;
    [self.connectionThread setStackSize:4096*64]; // 512k
    [self.connectionThread start];
    [self.connectionThread performSelector:@selector(connectTo:) onThread:self.connectionThread withObject:parameters waitUntilDone:YES];
}

#define MAX_ANNOTATIONS 50

- (void)locationToMap:(NSDictionary *)dictionary
{
    [self locationToMap:dictionary[@"LOCATION"] topic:dictionary[@"TOPIC"]];
}

- (void)locationToMap:(CLLocation *)location topic:(NSString *)topic
{
    Annotation *annotation = [[Annotation alloc] init];
    annotation.coordinate = location.coordinate;
    annotation.timeStamp = location.timestamp;
    annotation.topic = topic;
    
    [self.mapView addAnnotation:annotation];
    [self.annotationArray addObject:annotation];
    if ([self.annotationArray count] > MAX_ANNOTATIONS) {
        [self.mapView removeAnnotation:self.annotationArray[0]];
        [self.annotationArray removeObjectAtIndex:0];
    }
}

- (void)publishLocation:(CLLocation *)location
{
    [self.mapView setCenterCoordinate:location.coordinate animated:YES];
    [self locationToMap:location topic:self.topic];
    
    NSData *data = [self formatLocationData:location withType:@"location"];
    
    NSDictionary *parameters = @{@"DATA": data,
                                 @"TOPIC": self.topic,
                                 @"QOS": [NSString stringWithFormat:@"%d", self.qos],
                                 @"RETAINFLAG": [NSString stringWithFormat:@"%d", self.retainFlag]
                                 };
    if (!self.connectionThread || !self.connectionThread.isExecuting) {
        [self connect];
    }
    [self.connectionThread performSelector:@selector(sendData:) onThread:self.connectionThread withObject:parameters waitUntilDone:YES];
}

- (NSData *)formatLocationData:(CLLocation *)location withType:(NSString *)type
{
    NSDictionary *fullJsonObject = @{
                                     @"lat": [NSString stringWithFormat:@"%f", location.coordinate.latitude],
                                     @"lon": [NSString stringWithFormat:@"%f", location.coordinate.longitude],
                                     @"tst": [NSString stringWithFormat:@"%.0f", [location.timestamp timeIntervalSince1970]],
                                     @"acc": [NSString stringWithFormat:@"%.0fm", location.horizontalAccuracy],
                                     @"alt": [NSString stringWithFormat:@"%f", location.altitude],
                                     @"vac": [NSString stringWithFormat:@"%.0fm", location.verticalAccuracy],
                                     @"vel": [NSString stringWithFormat:@"%f", location.speed],
                                     @"dir": [NSString stringWithFormat:@"%f", location.course],
                        /*testing*/  @"_pow": [NSString stringWithFormat:@"%f", ([[UIDevice currentDevice] isBatteryMonitoringEnabled]) ? [[UIDevice currentDevice] batteryLevel] : -1.0 ],
                                     @"_type": [NSString stringWithFormat:@"%@", type]
                                     };
    NSDictionary *smallJsonObject = @{
                                      @"tst": [NSString stringWithFormat:@"%.0f", [location.timestamp timeIntervalSince1970]],
                                      @"_type": [NSString stringWithFormat:@"%@", type]
                                      };
    
    
    NSDictionary *jsonObjects = @{
                                  @"location": fullJsonObject,
                                  @"lwt": smallJsonObject
                                  };

    NSData *data;
    
    
    if ([NSJSONSerialization isValidJSONObject:jsonObjects[type]]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObjects[type] options:0 /* not pretty printed */ error:&error];
        if (!data) {
            [self.logs log:[error description]];
        }
    } else {
        [self.logs log:[NSString stringWithFormat:@"No valid JSON Object: %@", [jsonObjects[type] description]]];
    }
    return data;
}

/* Called from LocationManager when location changes significantly
 *
 */

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"Significant Location Change");

    if (self.background) {
        for (CLLocation *location in locations) {
            NSLog(@"Location: %@", [location description]);
            [self publishLocation:location];
        }        
    }
}

/* UI Actions
 *
 */

- (IBAction)publishNow:(UIBarButtonItem *)sender {
    [self publishLocation:self.manager.location];
}

- (IBAction)stop:(UIBarButtonItem *)sender {
    if (self.connectionThread && self.connectionThread.isExecuting) {
        [self.connectionThread performSelector:@selector(disconnect) onThread:self.connectionThread withObject:Nil waitUntilDone:YES];
    }
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
        
        if (self.connectionThread && self.connectionThread.isExecuting) {
            [self.connectionThread performSelector:@selector(disconnect) onThread:self.connectionThread withObject:Nil waitUntilDone:YES];
        }

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

#define HOST_DEFAULT @"test.mosquitto.org"
#define PORT_DEFAULT 1883
#define TLS_DEFAULT FALSE
#define AUTH_DEFAULT FALSE
#define USER_DEFAULT @""
#define PASS_DEFAULT @""

#define TOPIC_DEFAULT @"mqttitude"
#define RETAIN_DEFAULT TRUE
#define QOS_DEFAULT 2
#define BACKGROUND_DEFAULT FALSE


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
        
        self.topic = TOPIC_DEFAULT;
        self.retainFlag = RETAIN_DEFAULT;
        self.qos = QOS_DEFAULT;
        self.background = BACKGROUND_DEFAULT;
        [self synchronizeSettings];
    }
}

/* Communication from Background Thread
 *
 */

- (void)showStatus:(NSString *)status
{
    self.statusField.text = status;
}

- (void)showIndicator:(NSNumber *)indicator
{
    UIColor *color;
    
    switch ([indicator integerValue]) {
        case INDICATOR_GREEN:
            color = [UIColor greenColor];
            break;
        case INDICATOR_YELLOW:
            color = [UIColor yellowColor];
            break;
        case INDICATOR_RED:
            color = [UIColor redColor];
            break;
        case INDICATOR_IDLE:
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

@end
