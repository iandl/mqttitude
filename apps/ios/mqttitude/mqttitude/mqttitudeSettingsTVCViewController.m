//
//  LongitudeSettingsTVCViewController.m
//  Longitude
//
//  Created by Christoph Krey on 15.07.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "mqttitudeSettingsTVCViewController.h"

@interface mqttitudeSettingsTVCViewController()
@property (weak, nonatomic) IBOutlet UITextField *UIhost;
@property (weak, nonatomic) IBOutlet UISwitch *UItls;
@property (weak, nonatomic) IBOutlet UITextField *UIport;
@property (weak, nonatomic) IBOutlet UITextField *UItopic;
@property (weak, nonatomic) IBOutlet UISwitch *UIretainFlag;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UIqos;
@end

@implementation mqttitudeSettingsTVCViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.UIhost.text = self.host;
    self.UIport.text = [NSString stringWithFormat:@"%d", (unsigned int)self.port];
    self.UItopic.text = self.topic;
    self.UItls.on = self.tls;
    self.UIretainFlag.on = self.retainFlag;
    self.UIqos.selectedSegmentIndex = self.qos;
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

@end
