//
//  LongitudeSettingsTVCViewController.m
//  Longitude
//
//  Created by Christoph Krey on 15.07.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "mqttitudeSettingsTVCViewController.h"
#import "mqttitudeQoSTVC.h"

@interface mqttitudeSettingsTVCViewController()
@property (weak, nonatomic) IBOutlet UITextField *UIhost;
@property (weak, nonatomic) IBOutlet UISwitch *UItls;
@property (weak, nonatomic) IBOutlet UITextField *UIuser;
@property (weak, nonatomic) IBOutlet UITextField *UIpass;
@property (weak, nonatomic) IBOutlet UISwitch *UIauth;
@property (weak, nonatomic) IBOutlet UITextField *UIport;
@property (weak, nonatomic) IBOutlet UITextField *UItopic;
@property (weak, nonatomic) IBOutlet UISwitch *UIretainFlag;
@property (weak, nonatomic) IBOutlet UITextField *UIqos;
@property (weak, nonatomic) IBOutlet UITextField *UIversion;
@end

@implementation mqttitudeSettingsTVCViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.UIhost.text = self.host;
    self.UIport.text = [NSString stringWithFormat:@"%d", (unsigned int)self.port];
    self.UItls.on = self.tls;
    self.UIauth.on = self.auth;
    self.UIuser.text = self.user;
    self.UIpass.text = self.pass;
    self.UItopic.text = self.topic;
    self.UIretainFlag.on = self.retainFlag;
    
    self.UIqos.text = [self qosString:self.qos];

    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    self.UIversion.text = [NSString stringWithFormat:@"%@ %@",  info[@"CFBundleName"], info[@"CFBundleShortVersionString"]];;
}

- (IBAction)hostEditingChanged:(UITextField *)sender {
    self.host = sender.text;
}
- (IBAction)tlsChange:(UISwitch *)sender {
    self.tls = sender.on;
}
- (IBAction)portEditingChanged:(UITextField *)sender {
    self.port = [sender.text integerValue];
}
- (IBAction)topicEditingChanged:(UITextField *)sender {
    self.topic =sender.text;
}
- (IBAction)retainFlagChanged:(UISwitch *)sender {
    self.retainFlag = sender.on;
}
- (IBAction)qosChange:(UISegmentedControl *)sender {
    self.qos = sender.selectedSegmentIndex;
}
- (IBAction)authChange:(UISwitch *)sender {
    self.auth = sender.on;
}
- (IBAction)userChange:(UITextField *)sender {
    self.user = sender.text;
}
- (IBAction)passChange:(UITextField *)sender {
    self.pass = sender.text;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[mqttitudeQoSTVC class]]) {
        mqttitudeQoSTVC *qos = (mqttitudeQoSTVC *)segue.destinationViewController;
        qos.qos = self.qos;
    }
}


- (IBAction)settingsSaved:(UIStoryboardSegue *)seque
{
    if ([seque.sourceViewController isKindOfClass:[mqttitudeQoSTVC class]]) {
        mqttitudeQoSTVC *qos = (mqttitudeQoSTVC *)seque.sourceViewController;
        self.qos = qos.qos;
        self.UIqos.text = [self qosString:self.qos];
    }
}

- (NSString *)qosString:(NSInteger)qos
{
    NSArray *qosStrings = @[
                            NSLocalizedString(@"At most once", @"MQTT QoS 0"),
                            NSLocalizedString(@"At least once", @"MQTT QoS 1"),
                            NSLocalizedString(@"Exactly once", @"MQTT QoS 2")
                            ];
    
    if (qos < [qosStrings count]) {
        return qosStrings[self.qos];
    } else {
        return @"MQTTitude unknown QoS";
    }
}



@end
