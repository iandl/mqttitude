//
//  mqttitudeLogTVCViewController.m
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "mqttitudeLogTVCViewController.h"
#import "Logs.h"

@interface mqttitudeLogTVCViewController ()

@end

@implementation mqttitudeLogTVCViewController

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.logs count];
}

#define MESSAGE @"log"

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell= [tableView dequeueReusableCellWithIdentifier:MESSAGE
                                                           forIndexPath:indexPath];
    
    LogEntry *logEntry = [self.logs elementAtPosition:indexPath.row];
    
    cell.textLabel.text = [NSDateFormatter localizedStringFromDate:logEntry.timestamp
                                                         dateStyle:NSDateFormatterShortStyle
                                                         timeStyle:NSDateFormatterMediumStyle];
    cell.detailTextLabel.text = logEntry.message;
    
    return cell;
}



@end
