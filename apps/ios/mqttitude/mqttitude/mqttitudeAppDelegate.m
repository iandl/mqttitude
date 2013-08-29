//
//  mqttitudeAppDelegate.m
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "mqttitudeAppDelegate.h"
@interface mqttitudeAppDelegate()
@property UIBackgroundTaskIdentifier activeBackgroundTask;
@end

@implementation mqttitudeAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
#ifdef DEBUG
    NSLog(@"application didFinishLaunchingWithOptions");
    NSEnumerator *enumerator = [launchOptions keyEnumerator];
    NSString *key;
    while ((key = [enumerator nextObject])) {
        NSLog(@"%@:%@", key, [[launchOptions objectForKey:key] description]);
    }
#endif
    self.activeBackgroundTask = UIBackgroundTaskInvalid;
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
#ifdef DEBUG
    NSLog(@"applicationWillResignActive");
#endif
}

- (void)expirationHandler
{
#ifdef DEBUG
    NSLog(@"ExpirationHandler remaining: %10.3f", [UIApplication sharedApplication].backgroundTimeRemaining);
#endif
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
#ifdef DEBUG
    NSLog(@"applicationDidEnterBackground");
#endif
    [self.manager stopMonitoringSignificantLocationChanges];
#ifdef DEBUG
    NSLog(@"stopMonitoringSignificantLocationChanges done");
#endif

    
    self.activeBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self expirationHandler];
    }];
#ifdef DEBUG
    if (self.activeBackgroundTask == UIBackgroundTaskInvalid) {
        NSLog(@"Backgroundtasks Invalid");
    }
#endif
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
#ifdef DEBUG
    NSLog(@"applicationWillEnterForeground");
#endif
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
#ifdef DEBUG
    NSLog(@"applicationDidBecomeActive");
#endif
    [self.manager startMonitoringSignificantLocationChanges];
#ifdef DEBUG
    NSLog(@"startMonitoringSignificantLocationChanges done");
#endif
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
#ifdef DEBUG
    NSLog(@"applicationWillTerminate");
#endif
}

@end
