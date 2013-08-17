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
#import "Location.h"
#import "LogEntry.h"


@interface mqttitudeViewController ()
@property (strong, nonatomic) MQTTSession *session;
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) NSString *clientId;

@property (strong, nonatomic) NSString *topic;
@property (nonatomic) BOOL tls;
@property (nonatomic) BOOL retainFlag;
@property (nonatomic) NSInteger qos;
@property (strong, nonatomic) NSString *host;
@property (nonatomic) UInt32 port;
@property (strong, nonatomic) NSMutableArray *logArray;

@property (weak, nonatomic) IBOutlet MKMapView *map;
@property (weak, nonatomic) IBOutlet UITextField *status;

@end

@implementation mqttitudeViewController

#define SETTINGS_KEY @"SETTINGS"
#define HOST_KEY @"HOST"
#define PORT_KEY @"PORT"
#define TOPIC_KEY @"TOPIC"
#define TLS_KEY @"TLS"
#define RETAIN_KEY @"RETAIN"
#define QOS_KEY @"QOS"

#define HOST_DEFAULT @"test.mosquitto.org"
#define PORT_DEFAULT 1883
#define TOPIC_DEFAULT @"mqttitude"
#define TLS_DEFAULT FALSE
#define RETAIN_DEFAULT TRUE
#define QOS_DEFAULT 2

- (void)synchronizeSettings
{
    [[NSUserDefaults standardUserDefaults] setObject:@{
                                            HOST_KEY:self.host,
                                            PORT_KEY:@(self.port),
                                           TOPIC_KEY:self.topic,
                                             TLS_KEY:@(self.tls),
                                          RETAIN_KEY:@(self.retainFlag),
                                             QOS_KEY:@(self.qos)}
                                              forKey:SETTINGS_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)settingsFromPropertyList
{
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SETTINGS_KEY];
    
    if (settings) {
        self.host = settings[HOST_KEY];
        self.topic = settings[TOPIC_KEY];
        self.port = [settings[PORT_KEY] intValue];
        self.tls = [settings[TLS_KEY] boolValue];
        self.retainFlag = [settings[RETAIN_KEY] boolValue];
        self.qos = [settings[QOS_KEY] intValue];
    } else {
        self.host = HOST_DEFAULT;
        self.port = PORT_DEFAULT;
        self.topic = TOPIC_DEFAULT;
        self.tls = TLS_DEFAULT;
        self.retainFlag = RETAIN_DEFAULT;
        self.qos = QOS_DEFAULT;
        [self synchronizeSettings];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.logArray = [[NSMutableArray alloc] init];
    
    if ([CLLocationManager locationServicesEnabled]) {
        self.manager = [[CLLocationManager alloc] init];
        self.manager.delegate = self;
        
    } else {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        [self log:[NSDate date] message:[NSString stringWithFormat:@"Not authorized for CoreLocation %d", status]];
        
    }
    
    [self settingsFromPropertyList];
    [self connect];
}

#pragma mark - MQtt Callback methods

- (void)session:(MQTTSession*)sender handleEvent:(MQTTSessionEvent)eventCode {
    switch (eventCode) {
        case MQTTSessionEventConnected:
            self.status.text = @"connected";
            break;
        case MQTTSessionEventConnectionRefused:
            self.status.text = @"connection refused";            
            break;
        case MQTTSessionEventConnectionClosed:
            self.status.text = @"connection closed";
            
            break;
        case MQTTSessionEventConnectionError:
            self.status.text = @"connection error, reconnecting...";
            [self log:[NSDate date] message:self.status.text];
            
            // Forcing reconnection
            [self.session connectToHost:self.host port:self.port];
            break;
        case MQTTSessionEventProtocolError:
            self.status.text = @"protocol error";
            break;
        default:
            self.status.text = [NSString stringWithFormat:@"unknown eventCode: %d", eventCode];
            break;
    }
    [self log:[NSDate date] message:self.status.text];

}

- (void)connect
{
    if (!self.session) {
        self.clientId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        
        self.session = [[MQTTSession alloc] initWithClientId:self.clientId];
        [self.session setDelegate:self];
        [self.session connectToHost:self.host
                               port:self.port];
    }
    if (self.manager) {
        [self.manager startMonitoringSignificantLocationChanges];
    }
}

- (void)disconnect
{
    if (self.session) {
        [self.session close];
        self.session = nil;
    }
    if (self.manager) {
        [self.manager stopMonitoringSignificantLocationChanges];
    }
    
    [self.map removeAnnotations:self.map.annotations];
}

- (IBAction)publishNow:(UIBarButtonItem *)sender {
    [self publishLocation:self.manager.location];
}

- (void)publishLocation:(CLLocation *)location
{
    if (location) {
        [self.map setCenterCoordinate:location.coordinate animated:YES];
        [self.map setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
        
        Location *locationAnnotation = [[Location alloc] init];
        locationAnnotation.coordinate = location.coordinate;
        locationAnnotation.timeStamp = location.timestamp;
        [self.map addAnnotation:locationAnnotation];
        
        NSString *json = [NSString stringWithFormat:
                          @"{\"lat\": \"%f\", \"lon\": \"%f\", \"tst\": \"%.0f\", \"acc\": \"%.0fm\",}",
                          location.coordinate.latitude,
                          location.coordinate.longitude,
                          [location.timestamp timeIntervalSince1970],
                          location.horizontalAccuracy
                          ];
        
        if (self.session) {
            NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
            
            [self log:location.timestamp message:json];
            
            switch (self.qos) {
                case 0:
                    [self.session publishDataAtMostOnce:data onTopic:[NSString stringWithFormat:@"%@", self.topic] retain:self.retainFlag];
                    break;
                case 1:
                    [self.session publishDataAtLeastOnce:data onTopic:[NSString stringWithFormat:@"%@", self.topic] retain:self.retainFlag];
                    break;
                case 2:
                    [self.session publishDataExactlyOnce:data onTopic:[NSString stringWithFormat:@"%@", self.topic] retain:self.retainFlag];
                    break;
                default:
                    NSLog(@"Unknown qos: %d", self.qos);
                    break;                    
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    
    /*
     If you start this service and your application is subsequently terminated, the system automatically relaunches the application into the background if a new event arrives. In such a case, the options dictionary passed to the locationManager:didUpdateLocations: method of your application delegate contains the key UIApplicationLaunchOptionsLocationKey to indicate that your application was launched because of a location event. Upon relaunch, you must still configure a location manager object and call this method to continue receiving location events. When you restart location services, the current event is delivered to your delegate immediately. In addition, the location property of your location manager object is populated with the most recent location object even before you start location services.
     
     In addition to your delegate object implementing the locationManager:didUpdateLocations: method, it should also implement the locationManager:didFailWithError: method to respond to potential errors.
     
     Note: Apps can expect a notification as soon as the device moves 500 meters or more from its previous notification. It should not expect notifications more frequently than once every five minutes. If the device is able to retrieve data from the network, the location manager is much more likely to deliver notifications in a timely manner.
     
     */
    for (CLLocation *location in locations) {
        [self publishLocation:location];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[mqttitudeSettingsTVCViewController class]]) {
        mqttitudeSettingsTVCViewController *settings = (mqttitudeSettingsTVCViewController *)segue.destinationViewController;
        settings.host = self.host;
        settings.port = self.port;
        settings.tls = self.tls;
        settings.topic = self.topic;
        settings.retainFlag = self.retainFlag;
        settings.qos = self.qos;
    } else if ([segue.destinationViewController isKindOfClass:[mqttitudeLogTVCViewController class]]) {
        mqttitudeLogTVCViewController *logs = (mqttitudeLogTVCViewController *)segue.destinationViewController;
        logs.logArray = self.logArray;
    }
}

- (IBAction)settingsSaved:(UIStoryboardSegue *)seque
{
    if ([seque.sourceViewController isKindOfClass:[mqttitudeSettingsTVCViewController class]]) {
        mqttitudeSettingsTVCViewController *settings = (mqttitudeSettingsTVCViewController *)seque.sourceViewController;
        [self disconnect];
        self.host = settings.host;
        self.port = settings.port;
        self.topic = settings.topic;
        self.retainFlag = settings.retainFlag;
        self.qos = settings.qos;
        [self synchronizeSettings];
        [self connect];
    }
}


#define MAX_LOGS 50

- (void)log:(NSDate *)timestamp message:(NSString *)message
{
    NSLog(@"%@", message);

    LogEntry *logEntry = [[LogEntry alloc] init];
    logEntry.timestamp = timestamp;
    logEntry.message = message;
    [self.logArray insertObject:logEntry atIndex:0];
    if ([self.logArray count] > MAX_LOGS) {
        [self.logArray removeLastObject];
    }
}

@end
