//
//  ViewController.h
//  opticalFlowTest
//
//  Created by Jason Clark on 1/14/13.
//  Copyright (c) 2013 GTCMT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/highgui/cap_ios.h>
#import "AppDelegate.h"

@interface ViewController : UIViewController <CvVideoCameraDelegate>{
    IBOutlet UIImageView* imageView;
    IBOutlet UIButton* button;
    
    IBOutlet UILabel *trackNameLabel;
    IBOutlet UILabel *artistNameLabel;
    IBOutlet UILabel *energyLabel;
    IBOutlet UILabel *tempoLabel;
    
    bool cameraRunning;
    CvVideoCamera* videoCamera;
    AppDelegate *appDelegate;
    
    int selectedSongIndex;
}

@property (nonatomic,strong) IBOutlet UILabel *fpsLabel;
@property (nonatomic,strong) CvVideoCamera* videoCamera;

@property (nonatomic,strong) IBOutlet UILabel *trackNameLabel;
@property (nonatomic,strong) IBOutlet UILabel *artistNameLabel;
@property (nonatomic,strong) IBOutlet UILabel *energyLabel;
@property (nonatomic,strong) IBOutlet UILabel *tempoLabel;

@property (nonatomic,strong) NSMutableArray *selectedSongs;

- (IBAction)actionStart:(id)sender;


@end
