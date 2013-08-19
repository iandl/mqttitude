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
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSTimer *keepalive;

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

#define KEEP_ALIVE 30

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
    
    self.keepalive = [NSTimer timerWithTimeInterval:KEEP_ALIVE target:self selector:@selector(stillhere ) userInfo:Nil repeats:TRUE];
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
    [runLoop addTimer:self.keepalive forMode:NSDefaultRunLoopMode];

    [self connect];

    if (self.manager) {
        [self.manager startMonitoringSignificantLocationChanges];
    }
}

- (void)stillhere
{
    UIApplicationState state =  [[UIApplication sharedApplication] applicationState];
    NSLog(@"ApplicationState: %d, time remaining %10.3f",
          state,
          (state == UIApplicationStateBackground) ?
          [UIApplication sharedApplication].backgroundTimeRemaining :
            0.0);
}

#pragma mark - MQtt Callback methods
#define RECONNECT_SLEEP 10.0

- (void)session:(MQTTSession*)sender handleEvent:(MQTTSessionEvent)eventCode {
    switch (eventCode) {
        case MQTTSessionEventConnected:
            [self sessionMessage: NSLocalizedString(@"connected",
                                                 @"Status messsage to the user MQTT is connected to host")];
            break;
        case MQTTSessionEventConnectionRefused:
            [self sessionMessage: NSLocalizedString(@"refused",
                                                    @"Status messsage to the user MQTT connect to host was refused")];
            [self disconnect];
            break;
        case MQTTSessionEventConnectionClosed:
            [self sessionMessage: NSLocalizedString(@"closed",
                                                 @"Status messsage to the user MQTT connection to host was closed")];
            break;
        case MQTTSessionEventConnectionError:
        {
            [self sessionMessage:NSLocalizedString(@"connection error",
                                                 @"Status messsage to the user MQTT connection problem")];
            //Forcing reconnection
            [self.timer invalidate];
            self.session = nil;
            self.timer = [NSTimer timerWithTimeInterval:RECONNECT_SLEEP target:self selector:@selector(reconnect) userInfo:Nil repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
            [runLoop addTimer:self.timer forMode:NSDefaultRunLoopMode];
            break;
        }
        case MQTTSessionEventProtocolError:
            [self sessionMessage:NSLocalizedString(@"protocol error",
                                                 @"Status messsage to the user MQTT detected a protocol error")];
            break;      
        default:
            [self sessionMessage:[NSString stringWithFormat:@"MQTTitude unknown eventCode: %d", eventCode]];
            break;
    }
}

- (void)sessionMessage:(NSString *)message
{
    NSString *sessionMessage = [NSString stringWithFormat:@"%@ (%@%@:%d TLS=%@)",
                         message,
                         (self.auth) ? [NSString stringWithFormat:@"%@@", self.user] : @"",
                         self.host,
                         (unsigned int)self.port,
                         (self.tls) ? @"ON" : @"OFF"
                         ];
    self.status.text = sessionMessage;
    [self log:[NSDate date] message:sessionMessage];
}

- (void)reconnect
{
    self.timer = nil;
    [self sessionMessage:NSLocalizedString(@"reconnect",
                                           @"Status messsage to the user MQTT reconnect")];
    [self connect];
}

- (void)session:(MQTTSession *)session newMessage:(NSData *)data onTopic:(NSString *)topic
{
    NSLog(@"%@: %@", topic, [self dataToString:data]);
    [self publishLocation:self.manager.location];
}

#define LISTENTO @"LISTENTO"

- (void)connect
{
    [self.timer invalidate];
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
        [self.session subscribeTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]];
    }
}

- (void)disconnect
{
    [self.timer invalidate];
    if (self.session) {
        [self.session unsubscribeTopic:[NSString stringWithFormat:@"%@/%@", self.topic, LISTENTO]];
        [self.session close];
        self.session = nil;
    }
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
                                     @"_type": [NSString stringWithFormat:@"%@", @"location"]
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
            NSString *message = [self dataToString:data];
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



@end
