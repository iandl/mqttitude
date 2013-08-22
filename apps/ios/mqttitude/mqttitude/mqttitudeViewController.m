//
//  mqttitudeViewController.m
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//
#define MULTI_THREADING

#import "mqttitudeViewController.h"
#import "mqttitudeSettingsTVCViewController.h"
#import "mqttitudeLogTVCViewController.h"
#import "Annotation.h"
#import "Logs.h"
#import "ConnectionThread.h"

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
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;

@property (strong, nonatomic) ConnectionThread *connectionThread;

@end

@implementation mqttitudeViewController



/* Setup
 *
 * Settings, Arrays, KeepAlive Timer, Location Manager
 *
 */
#define KEEP_ALIVE 30

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self settingsFromPropertyList];
    
    self.annotationArray = [[NSMutableArray alloc] init];
    self.logs = [[Logs alloc] init];
    
    [self.logs log:[NSString stringWithFormat:@"%@ starting...",
                    [NSString stringWithFormat:@"%@ %@",
                     [NSBundle mainBundle].infoDictionary[@"CFBundleName"],
                     [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"]]]];
        
    self.keepalive = [NSTimer timerWithTimeInterval:KEEP_ALIVE target:self selector:@selector(stillhere ) userInfo:Nil repeats:TRUE];
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
    [runLoop addTimer:self.keepalive forMode:NSDefaultRunLoopMode];
    
    /* for Testing */ [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    
    if ([CLLocationManager locationServicesEnabled]) {
        self.manager = [[CLLocationManager alloc] init];
        self.manager.delegate = self;
        [self.manager startMonitoringSignificantLocationChanges];
    } else {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        [self.logs log:[NSString stringWithFormat:@"MQTTitude not authorized for CoreLocation %d", status]];
        
    }
    self.ConnectionThread = [[ConnectionThread alloc] init];
    self.connectionThread.controller = self;
    [self.connectionThread setStackSize:4096*1000]; //No idea if this is an appropriate value
    [self.connectionThread start];
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
    
    [self.connectionThread performSelector:@selector(connectTo:) onThread:self.connectionThread withObject:parameters waitUntilDone:YES];
}

#define MAX_ANNOTATIONS 20

- (void)publishLocation:(CLLocation *)location
{
    if (location) {
        [self.mapView setCenterCoordinate:location.coordinate animated:YES];
        [self.mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
        
        Annotation *annotation = [[Annotation alloc] init];
        annotation.coordinate = location.coordinate;
        annotation.timeStamp = location.timestamp;

        [self.mapView addAnnotation:annotation];
        [self.annotationArray addObject:annotation];
        if ([self.annotationArray count] > MAX_ANNOTATIONS) {
            [self.mapView removeAnnotation:self.annotationArray[0]];
            [self.annotationArray removeObjectAtIndex:0];
        }
        
        NSData *data = [self formatLocationData:location withType:@"location"];

        NSDictionary *parameters = @{@"DATA": data,
                                     @"TOPIC": self.topic,
                                     @"QOS": [NSString stringWithFormat:@"%d", self.qos],
                                     @"RETAINFLAG": [NSString stringWithFormat:@"%d", self.retainFlag]
                                     };

        [self.connectionThread performSelector:@selector(sendData:) onThread:self.connectionThread withObject:parameters waitUntilDone:YES];
    }
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
                                     /* testing */ @"_pow": [NSString stringWithFormat:@"%f", ([[UIDevice currentDevice] isBatteryMonitoringEnabled]) ?
                                                             [[UIDevice currentDevice] batteryLevel] : -1.0 ],
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

    if (([UIApplication sharedApplication].applicationState == UIApplicationStateActive) || self.background) {
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
        
        [self.connectionThread performSelector:@selector(disconnect) onThread:self.connectionThread withObject:Nil waitUntilDone:NO];

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

#define HOST_DEFAULT @"roo.jpmens.net"
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

- (void)publishNow
{
    [self publishLocation:self.manager.location];
}

- (void)log:(NSString *)message
{
    [self.logs log:message];
}


@end
