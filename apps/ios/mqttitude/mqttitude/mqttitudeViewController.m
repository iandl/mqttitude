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
#import <AddressBookUI/AddressBookUI.h>

@interface mqttitudeViewController ()
@property (strong, nonatomic) MQTTSession *session;
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) NSString *clientId;
@property (strong, nonatomic) CLGeocoder *geocoder;

@property (strong, nonatomic) NSString *topic;
@property (nonatomic) BOOL retainFlag;
@property (nonatomic) NSInteger qos;

@property (strong, nonatomic) NSString *host;
@property (nonatomic) UInt32 port;
@property (nonatomic) BOOL tls;
@property (nonatomic) BOOL auth;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *pass;

@property (strong, nonatomic) NSMutableArray *logArray;
@property (strong, nonatomic) NSMutableArray *annotationArray;

@property (weak, nonatomic) IBOutlet MKMapView *map;
@property (weak, nonatomic) IBOutlet UITextField *status;
@property (weak, nonatomic) IBOutlet UITextView *placeMark;


@end

@implementation mqttitudeViewController

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

#define HOST_DEFAULT @"roo.jpmens.net"
#define PORT_DEFAULT 1883
#define TLS_DEFAULT FALSE
#define AUTH_DEFAULT FALSE
#define USER_DEFAULT @""
#define PASS_DEFAULT @""

#define TOPIC_DEFAULT @"mqttitude"
#define RETAIN_DEFAULT TRUE
#define QOS_DEFAULT 2

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
                                             QOS_KEY:@(self.qos)}
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
        [self synchronizeSettings];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.logArray = [[NSMutableArray alloc] init];
    self.annotationArray = [[NSMutableArray alloc] init];
    
    if ([CLLocationManager locationServicesEnabled]) {
        self.manager = [[CLLocationManager alloc] init];
        self.manager.delegate = self;
    } else {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        [self log:[NSDate date] message:[NSString stringWithFormat:@"MQTTitude not authorized for CoreLocation %d", status]];
        
    }
    
    [self settingsFromPropertyList];
    [self connect];
}

#pragma mark - MQtt Callback methods

- (void)session:(MQTTSession*)sender handleEvent:(MQTTSessionEvent)eventCode {
    switch (eventCode) {
        case MQTTSessionEventConnected:
            self.status.text = NSLocalizedString(@"connected",
                                                 @"Status messsage to the user MQTT is connected to host");
            break;
        case MQTTSessionEventConnectionRefused:
            self.status.text = NSLocalizedString(@"connection refused",
                                                 @"Status messsage to the user MQTT connect to host was refused");
            break;
        case MQTTSessionEventConnectionClosed:
            self.status.text = NSLocalizedString(@"connection closed",
                                                 @"Status messsage to the user MQTT connection to host was closed");
            break;
        case MQTTSessionEventConnectionError:
            self.status.text = NSLocalizedString(@"connection error, reconnecting...",
                                                 @"Status messsage to the user MQTT connection problem, retrying");
            [self log:[NSDate date] message:self.status.text];
            
            // Forcing reconnection
            [self.session connectToHost:self.host port:self.port usingSSL:self.tls];
            break;
        case MQTTSessionEventProtocolError:
            self.status.text = NSLocalizedString(@"protocol error",
                                                 @"Status messsage to the user MQTT detected a protocol error");
            break;
        default:
            self.status.text = [NSString stringWithFormat:@"MQTTitude unknown eventCode: %d", eventCode];
            break;
    }
    [self log:[NSDate date] message:self.status.text];

}

- (void)connect
{
    if (!self.session) {
        self.clientId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        
        if (self.auth) {
            self.session = [[MQTTSession alloc] initWithClientId:self.clientId userName:self.user password:self.pass];
        } else {
            self.session = [[MQTTSession alloc] initWithClientId:self.clientId];
        }
        [self.session setDelegate:self];
        [self.session connectToHost:self.host
                               port:self.port
                           usingSSL:self.tls];
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

#define MAX_ANNOTATIONS 20

- (void)publishLocation:(CLLocation *)location
{
    if (location) {
        [self.map setCenterCoordinate:location.coordinate animated:YES];
        [self.map setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
        
        Location *locationAnnotation = [[Location alloc] init];
        locationAnnotation.coordinate = location.coordinate;
        locationAnnotation.timeStamp = location.timestamp;
        [self geocodeLocation:location annotation:locationAnnotation];

        [self.map addAnnotation:locationAnnotation];
        [self.annotationArray addObject:locationAnnotation];
        if ([self.annotationArray count] > MAX_ANNOTATIONS) {
            [self.map removeAnnotation:self.annotationArray[0]];
            [self.annotationArray removeObjectAtIndex:0];
        }
        
        NSDictionary *jsonObject = @{
                                     @"lat": [NSString stringWithFormat:@"%f", location.coordinate.latitude],
                                     @"lon": [NSString stringWithFormat:@"%f", location.coordinate.longitude],
                                     @"tst": [NSString stringWithFormat:@"%.0f", [location.timestamp timeIntervalSince1970]],
                                     @"acc": [NSString stringWithFormat:@"%.0fm", location.horizontalAccuracy],
                                     @"alt": [NSString stringWithFormat:@"%f", location.altitude],
                                     @"vac": [NSString stringWithFormat:@"%.0fm", location.verticalAccuracy],
                                     @"vel": [NSString stringWithFormat:@"%f", location.speed],
                                     @"dir": [NSString stringWithFormat:@"%f", location.course],
                                     @"mo": [NSString stringWithFormat:@"%@", @"unkown"]
                                     };
        NSData *data;
        
        if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
            NSError *error;
            data = [NSJSONSerialization dataWithJSONObject:jsonObject options:!NSJSONWritingPrettyPrinted error:&error];
            if (!data) {
                [self log:[NSDate date] message:[error description]];
            }
        } else {
            [self log:[NSDate date] message:[NSString stringWithFormat:@"No valid JSON Object: %@", [jsonObject description]]];
        }
        
        if (self.session) {
            /* the following lines are necessary to convert data which is possibly not null-terminated into a string */
            NSString *message = [[NSString alloc] init];
            for (int i = 0; i < data.length; i++) {
                char c;
                [data getBytes:&c range:NSMakeRange(i, 1)];
                message = [message stringByAppendingFormat:@"%c", c];
            }
            
            [self log:location.timestamp message:message];
            
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
                    NSLog(@"MQTTitude unknown qos: %d", self.qos);
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
        settings.auth = self.auth;
        settings.user = self.user;
        settings.pass = self.pass;
        
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
        self.tls = settings.tls;
        self.auth = settings.auth;
        self.user = settings.user;
        self.pass = settings.pass;
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

- (void)geocodeLocation:(CLLocation*)location annotation:(Location *)locationAnnotation
{
    if (!self.geocoder)
        self.geocoder = [[CLGeocoder alloc] init];
    
    [self.geocoder reverseGeocodeLocation:location completionHandler:
     ^(NSArray* placemarks, NSError* error){
         if ([placemarks count] > 0)
         {
             CLPlacemark *placemark = placemarks[0];
             self.placeMark.text = ABCreateStringWithAddressDictionary (placemark.addressDictionary, TRUE);
         } else {
             self.placeMark.text = [NSString stringWithFormat:@"%f %f",
                                    location.coordinate.latitude,
                                    location.coordinate.longitude];
         }
     }];
}

@end
