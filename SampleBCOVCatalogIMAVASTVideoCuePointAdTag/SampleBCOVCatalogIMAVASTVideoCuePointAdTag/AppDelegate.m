//
//  AppDelegate.m
//  SampleBCOVCatalogIMAVASTVideoCuePointAdTag
//
//  Created by Jim Whisenant on 6/24/14.
//  Copyright (c) 2014 Brightcove. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "AppDelegate.h"


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSError *setCategoryError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
    
    if (setCategoryError)
    {
        NSLog(@"AppDelegate Debug - Error setting AVAudioSession category.  Because of this, there may be no sound. %@", setCategoryError);
    }
    // Override point for customization after application launch.
    return YES;
}
							
@end
