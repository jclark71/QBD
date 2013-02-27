//
//  AppDelegate.h
//  opticalFlowTest
//
//  Created by Jason Clark on 1/14/13.
//  Copyright (c) 2013 GTCMT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CocoaLibSpotify.h"

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, SPSessionDelegate, SPSessionPlaybackDelegate>{
    SPPlaybackManager *_playbackManager;
	SPTrack *_currentTrack;
    SPSearch *_search;
}

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@property (nonatomic, strong) SPTrack *currentTrack;
@property (nonatomic, strong) SPSearch *search;
@property (nonatomic, strong) SPPlaybackManager *playbackManager;

-(void)playTrack:(NSURL *)url;
-(void)stopTrack;

@end
