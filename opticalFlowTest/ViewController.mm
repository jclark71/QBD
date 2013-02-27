//
//  ViewController.m
//  opticalFlowTest
//
//  Created by Jason Clark on 1/14/13.
//  Copyright (c) 2013 GTCMT. All rights reserved.
//

#include "ViewController.h"
#include "cvneon.h"
#include <time.h>
#import <math.h>
#import <AVFoundation/AVFoundation.h>
#include <algorithm>
#include "GCDAsyncUdpSocket.h"
#import "AppDelegate.h"


//echo nest

#import "ENAPI.h"

//spotify

#import "CocoaLibSpotify.h"


//Some constants
#define acThresh 100
#define maxCount 200
#define minDist 5
#define qLevel 0.01

#define maxTemp 150
#define minTemp 76


#define numPeaks 10
#define peakWidth 5

#define sendToShimi 0

#define salienceThresh 0.3



using namespace cv;

@interface ViewController (){
    
    //Image processing
    Mat image_prev, image_next;
    std::vector<Point2f> features_prev, features_next;
    std::vector<float> err;
    std::vector<unsigned char> status;
    bool recalibrate;
    cv::Mat m_mask;
    int recalibrate_num;
    
    //mag cacluation
    float x,y,mag,x1,y1;
    int points;
    
    //clock
//    clock_t start;
//    clock_t stop;
//    unsigned long millis;
    
    int64 tickCountStart;
    int64 tickCountEnd;
    double tickCountFrequency;
    double elapsed;
    
    int64 frameStart;
    int64 frameEnd;
    double frame;
    
    //autocorrelation
    int acCounter;
    float mags[acThresh];
    float xs[acThresh];
    float ys[acThresh];
    
    int tempos[numPeaks*3];
    int numTempos;
    
    bool songPlaying;
    bool activated;
    
    GCDAsyncUdpSocket *socket;
    NSMutableDictionary *audioPlayers;
    NSMutableDictionary *balladAudioPlayers;
    
    NSString *socketHost;
    int socketPort;
    
}

std::vector<std::pair<float, int>> findPeaks(float values[]);
float scaleTime(int lags, float lagTime);


@end

@implementation ViewController
@synthesize videoCamera, fpsLabel;
@synthesize trackNameLabel, tempoLabel, artistNameLabel, energyLabel;
@synthesize selectedSongs = _selectedSongs;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:imageView];
    [self.videoCamera setDefaultAVCaptureDevicePosition: AVCaptureDevicePositionFront];
    [self.videoCamera setDefaultAVCaptureSessionPreset:AVCaptureSessionPresetLow];
    [self.videoCamera setDefaultAVCaptureVideoOrientation:AVCaptureVideoOrientationPortrait];
    [self.videoCamera setGrayscaleMode:YES];
    [self.videoCamera setDefaultFPS:30];
    [self.videoCamera setDelegate:self];
    [self.videoCamera start];
    
    recalibrate = YES;
    recalibrate_num = 10;
    activated = NO;
    songPlaying = NO;
    
    acCounter = 0;
    numTempos = 0;
    
    frameStart = cvGetTickCount();
    tickCountFrequency = cvGetTickFrequency();
    
    if (sendToShimi){
    socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    socketHost = @"224.0.80.8";
    socketPort = 34565;
    }
    else{
    [self setUpAudioPlayers];
    }
    
    [ENAPI initWithApiKey:@"XQJ6S68P5PWV5LYVB"
              ConsumerKey:@"7d9e9caf1ccff2bb09309308a7108dbf"
          AndSharedSecret:@"nwuJ+U6CQNOySzKTlSXYmg"];
    
    [tempoLabel setText:@""];
    [energyLabel setText:@""];
    [artistNameLabel setText:@""];
    [trackNameLabel setText:@""];
    
    selectedSongIndex = 0;
    appDelegate= (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playError:) name:@"playError" object:nil];
    
    _selectedSongs = [[NSMutableArray alloc] initWithObjects: nil];
    
}

- (void)requestFinished:(ENAPIRequest *)request {
    NSAssert1(200 == request.responseStatusCode, @"Expected 200 OK, Got: %d", request.responseStatusCode);
    NSArray *songs = [request.response valueForKeyPath:@"response.songs"];
    
    
//    for (int i = 0; i<[songs count]; i++) {
//        NSLog(@"%@",[songs objectAtIndex:i]);
//    }
}


-(void)setUpAudioPlayers{
    
    audioPlayers = [[NSMutableDictionary alloc] initWithCapacity:8];
    balladAudioPlayers = [[NSMutableDictionary alloc] initWithCapacity:8];
    
    NSMutableDictionary *paths = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                             @"80-heyYa.aif",                   @"80",
                             @"90-livinLaVidaLoca.aif",         @"90",
                             @"100-independent.aif",            @"100",
                             @"110-hollabackGirl.aif",          @"110",
                             @"120-tikTok.aif",                 @"120",
                             @"130-sexyAndIKnowIt.mp3",         @"130",
                             @"140-feelGood.mp3",               @"140",
                             @"150-whatTheHell.mp3",            @"150",
                             nil
                             ];

    for(id key in paths) {
        NSString *thePath = [paths objectForKey:key];
        
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath],thePath]];
        NSError *error;
        AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        audioPlayer.numberOfLoops = -1;
        [audioPlayers setObject:audioPlayer forKey:key];
    }
    
    NSMutableDictionary *ballad_paths = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                  @"80-halo.mp3",                    @"80",
                                  @"90-aeroplaneOverTheSea.aif",     @"90",
                                  @"100-helloDelaware.aif",          @"100",
                                  @"110-wherever.aif",               @"110",
                                  @"120-dontWannaMissAThing.aif",    @"120",
                                  @"130-totalEclipse.aif",           @"130",
                                  @"140-amazed.aif",                 @"140",
                                  @"150-alreadyGone.aif",            @"150",
                                  nil
                                  ];
    
    for(id key in paths) {
        NSString *thePath = [ballad_paths objectForKey:key];
        
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath],thePath]];
        NSError *error;
        AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        audioPlayer.numberOfLoops = -1;
        [balladAudioPlayers setObject:audioPlayer forKey:key];
    }
    
}

-(void)stopAudioPlayers{
    
    for(NSString *key in audioPlayers){
        AVAudioPlayer *audioPlayer = [audioPlayers objectForKey:key];
        [audioPlayer stop];
    }
    
    for(NSString *key in balladAudioPlayers){
        AVAudioPlayer *audioPlayer = [balladAudioPlayers objectForKey:key];
        [audioPlayer stop];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(IBAction)actionStart:(id)sender{
    
    
//Normal Stuff -- \/
    
    if (activated) {
        activated = NO;
        [button setTitle:@"start" forState:UIControlStateNormal];
        if (!sendToShimi) {
            [self stopAudioPlayers];
            [appDelegate stopTrack];
        }
        
        [tempoLabel setText:@""];
        [energyLabel setText:@""];
        [artistNameLabel setText:@""];
        [trackNameLabel setText:@""];
        
        songPlaying = NO;
        recalibrate = YES;
        acCounter = 0;
        numTempos = 0;
        
    }
    else{
        [button setTitle:@"stop" forState:UIControlStateNormal];
        activated = YES;
    }

    
}

-(void)playSongWithTempo:(NSNumber*)tempo andSalience:(NSNumber*)salience{
    
    NSLog(@"play song: %i",[tempo intValue]);
    
    float theTempo = [tempo floatValue];
    float theSalience = [salience floatValue] * 2.f;
    float uSalience = theSalience + .2f;
    float lSalience = theSalience - .2f;
    
    if (uSalience > 1.0) {
        uSalience = 1.0;
    }
    
    if (lSalience < 0.0){
        lSalience = 0.0;
    }
    
    if (lSalience > 0.85){
        lSalience = 0.85;
        }
    
    
    //echoNest stuff
    
    ENAPIRequest *request = [ENAPIRequest requestWithEndpoint:@"song/search"];
    [request setIntegerValue:30 forParameter:@"results"];
    [request setFloatValue:(theTempo-5.f) forParameter:@"min_tempo"];
    [request setFloatValue:(theTempo+5.f) forParameter:@"max_tempo"];
    [request setFloatValue:0.8f forParameter:@"artist_min_familiarity"];
    [request setFloatValue:0.5 forParameter:@"min_danceability"];
    [request setFloatValue:lSalience forParameter:@"min_energy"];
    [request setFloatValue:uSalience forParameter:@"max_energy"];
    [request setValue:@"live:false" forParameter:@"song_type"];
    [request setValue:[NSArray arrayWithObjects:@"tracks", @"id:spotify-WW",@"audio_summary", nil]  forParameter:@"bucket"];
    [request startSynchronous];
    
    NSArray *songs = [request.response valueForKeyPath:@"response.songs"];
    //NSLog(@"Songs: %@",songs);
    
    
    //NSString *spotifyURL = @"";
    
    
//    for (NSDictionary *dict in songs){
//        
//        NSArray *tracks = [dict objectForKey:@"tracks"];
//        NSDictionary *info = [dict objectForKey:@"audio_summary"];
//        NSString *tempoString = [info objectForKey:@"tempo"];
//        NSString *energy = [info objectForKey:@"energy"];
//        NSString *artistName = [dict objectForKey:@"artist_name"];
//        NSString *trackName = [dict objectForKey:@"title"];
//        
//        if ([tracks count] > 0){
//            
//            NSDictionary *track = [tracks objectAtIndex:0];
//            NSString *foreign_id = [track objectForKey:@"foreign_id"];
//            
//            
//            spotifyURL = [foreign_id stringByReplacingOccurrencesOfString:@"spotify-WW" withString:@"spotify"];
//            
//            
//            
//            [appDelegate playTrack:[NSURL URLWithString:spotifyURL]];
//        
//            [energyLabel setText: [[NSString stringWithFormat:@"%@", energy] substringToIndex:4]];
//            [artistNameLabel setText:[NSString stringWithFormat:@"%@", artistName]];
//            [trackNameLabel setText:[NSString stringWithFormat:@"%@", trackName]];
//            [tempoLabel setText:[[NSString stringWithFormat:@"%@", tempoString] substringToIndex:5]];
//            
//
//                break;
//   
//        }
//        
//    }
    
    [_selectedSongs removeAllObjects];
    
    selectedSongIndex = 0;
    
    for (NSDictionary *dict in songs){
        
          NSArray *tracks = [dict objectForKey:@"tracks"];
//        NSDictionary *info = [dict objectForKey:@"audio_summary"];
//        NSString *tempoString = [info objectForKey:@"tempo"];
//        NSString *energy = [info objectForKey:@"energy"];
//        NSString *artistName = [dict objectForKey:@"artist_name"];
//        NSString *trackName = [dict objectForKey:@"title"];
        
        if ([tracks count] > 0){
            
            [_selectedSongs addObject:dict];
            
//            NSDictionary *track = [tracks objectAtIndex:0];
//            NSString *foreign_id = [track objectForKey:@"foreign_id"];
//            
//            
//            spotifyURL = [foreign_id stringByReplacingOccurrencesOfString:@"spotify-WW" withString:@"spotify"];
//            
//            
//            
//            [appDelegate playTrack:[NSURL URLWithString:spotifyURL]];
            
//            [energyLabel setText: [[NSString stringWithFormat:@"%@", energy] substringToIndex:4]];
//            [artistNameLabel setText:[NSString stringWithFormat:@"%@", artistName]];
//            [trackNameLabel setText:[NSString stringWithFormat:@"%@", trackName]];
//            [tempoLabel setText:[[NSString stringWithFormat:@"%@", tempoString] substringToIndex:5]];
            
            
//            break;
            
        }
        
    }
    
    [self tryToPlayNextSong];

        //appDelegate.search = [SPSearch searchWithSearchQuery:[NSString stringWithFormat:@"%@ %@",artist,title] inSession:[SPSession sharedSession]];
        

    
    
//    if ([salience floatValue] > salienceThresh) {
//        AVAudioPlayer *player = [audioPlayers valueForKey:[tempo stringValue]];
//        [player play];
//    }
//    else{
//        AVAudioPlayer *player = [balladAudioPlayers valueForKey:[tempo stringValue]];
//        [player play];
//    }
    
//    if (sendToShimi) {
//        NSData *data = [[tempo stringValue] dataUsingEncoding:NSUTF8StringEncoding];
//        [socket sendData:data toHost:socketHost port:socketPort withTimeout:-1 tag:11];
//    }
//    else{
//        AVAudioPlayer *player = [audioPlayers valueForKey:[tempo stringValue]];
//        [player play];
//    }
    
    songPlaying = YES;

}

-(void)playError:(NSNotification *)notification{
    [self tryToPlayNextSong];
}

-(void)tryToPlayNextSong{
    
    NSDictionary *currentSong = [_selectedSongs objectAtIndex:selectedSongIndex];
        NSDictionary *info = [currentSong objectForKey:@"audio_summary"];
        NSString *tempoString = [info objectForKey:@"tempo"];
        NSString *energy = [info objectForKey:@"energy"];
        NSString *artistName = [currentSong objectForKey:@"artist_name"];
        NSString *trackName = [currentSong objectForKey:@"title"];
    
    NSArray *tracks = [currentSong objectForKey:@"tracks"];
            NSDictionary *track = [tracks objectAtIndex:0];
            NSString *foreign_id = [track objectForKey:@"foreign_id"];


            NSString *spotifyURL = [foreign_id stringByReplacingOccurrencesOfString:@"spotify-WW" withString:@"spotify"];

            [appDelegate playTrack:[NSURL URLWithString:spotifyURL]];

            [energyLabel setText: [[NSString stringWithFormat:@"%@", energy] substringToIndex:4]];
            [artistNameLabel setText:[NSString stringWithFormat:@"%@", artistName]];
            [trackNameLabel setText:[NSString stringWithFormat:@"%@", trackName]];
            [tempoLabel setText:[[NSString stringWithFormat:@"%@", tempoString] substringToIndex:5]];
    
    selectedSongIndex++;

}


-(void)calculateFPS{
    
    frameEnd = cvGetTickCount();
    frame = (frameEnd-frameStart)/tickCountFrequency;
    frameStart = frameEnd;
    int fps = 1000000/frame;
    [fpsLabel setText:[NSString stringWithFormat:@"FPS = %i",fps]];
    
}


#pragma mark - Protocol CvVideoCameraDelegate

#ifdef __cplusplus

int calculateMode(std::vector<int> sortTempos){

    int most_found_element = sortTempos[0];
    int most_found_element_count = 0;
    int current_element = sortTempos[0];
    int current_element_count = 0;
    
    for (int i = 0; i<sortTempos.size(); i++) {
       // printf("sort: %i\n",sortTempos[i]);
        if (sortTempos[i]!=-1) {
    
        if (sortTempos[i] == current_element) {
            current_element_count++;
        }
    
        else{
            if (current_element_count > most_found_element_count) {
                most_found_element = current_element;
                most_found_element_count = current_element_count;
            }
            
            current_element = sortTempos[i];
            current_element_count = 1;
        }
        }
    }
    
    if (current_element_count > most_found_element_count) {
        most_found_element = current_element;
        most_found_element_count = current_element_count;
    }
    
    //printf("tempo = %i, count = %i\n",most_found_element,most_found_element_count);
    return most_found_element;
}

- (void)processImage:(Mat&)image;
{
    //[self calculateFPS];
    [self performSelectorOnMainThread:@selector(calculateFPS) withObject:nil waitUntilDone:NO];
    
    if (activated && !songPlaying) {
        
    if (recalibrate) {
        recalibrate = NO;
        
        [self findFeatures:image];
        
    }
    else{
    
        image_prev = image_next.clone();
        features_prev = features_next;
        //getGray(image, image_next);
        cv::extractChannel(image, image_next, 0);
        
        cv::calcOpticalFlowPyrLK(image_prev, image_next, features_prev, features_next, status, err);
        
        x1 = 0;
        y1 = 0;
        mag = 0;
        points = 0;
        
        for (size_t i=0; i<status.size(); i++)
        {
            if (status[i])
            {
                
                cv::circle(m_mask, features_prev[i], 15, cv::Scalar(0), CV_FILLED);
                cv::line(image, features_prev[i], features_next[i], CV_RGB(0,250,0));
                cv::circle(image, features_next[i], 3, CV_RGB(0,250,0), CV_FILLED);
                
                x = features_next[i].x - features_prev[i].x;
                y = features_next[i].y - features_prev[i].y;
                
                x1 +=x;
                y1 +=y;
                
                mag = mag+sqrt((x*x+y*y));
                points++;
            }
        }
        
        mags[acCounter] = mag/points;
        xs[acCounter] = x1/points;
        ys[acCounter] = y1/points;
        
        if (acCounter >= acThresh){
            
            tickCountEnd = cvGetTickCount();
            tickCountFrequency = cvGetTickFrequency();
            elapsed = (tickCountEnd-tickCountStart)/tickCountFrequency;
            
            printf("\nelapsed = %f\n",elapsed);
            acCounter = 0;
            
            for (int i = 0; i<sizeof(tempos)/sizeof(int); i++) {
                tempos[i]=-1;
            }
            numTempos = 0;
            
            printf("\nmags\n");
            std::vector<int>magTempos = calculateAutocorrelation(mags, elapsed);
            for (int i = 0; i<numPeaks; i++) {
                if (magTempos[i] != -1){
                    tempos[numTempos] = magTempos[i];
                    numTempos++;
                }
                else break;
            }
            printf("\nxs\n");

            std::vector<int>xTempos = calculateAutocorrelation(xs, elapsed);
            for (int i = 0; i<numPeaks; i++) {
                if (xTempos[i] != -1){
                    tempos[numTempos] = xTempos[i];
                    numTempos++;
                }
                else break;
            }
            printf("\nys\n");

            std::vector<int>yTempos = calculateAutocorrelation(ys, elapsed);
            for (int i = 0; i<numPeaks; i++) {
                if (yTempos[i] != -1){
                    tempos[numTempos] = yTempos[i];
                    numTempos++;
                }
                else break;
            }
            
            std::vector<int>vectorTempos;
            
            for (int j = 0;j<sizeof(tempos)/sizeof(int); j++){

                vectorTempos.push_back(tempos[j]);
            }
            
            std::sort(vectorTempos.begin(),vectorTempos.end());
            std::reverse(vectorTempos.begin(), vectorTempos.end());
            
            //calculate beat salience/ entropy
            int nOrder = 1;
            
            float magDiff[acThresh-nOrder];
            float xDiff[acThresh-nOrder];
            float yDiff[acThresh-nOrder];
            
            float maxMagDiff = 0.0, maxXDiff = 0.0, maxYDiff = 0.0;
            
            for (int i = 0; i<acThresh-nOrder; i++) {
                magDiff[i] = fabs(mags[i+nOrder]-mags[i]);
//                if (magDiff[i]>maxMagDiff) {
//                    maxMagDiff = magDiff[i];
//                }
                maxMagDiff += magDiff[i];
                
                xDiff[i] = fabs(xs[i+nOrder]-xs[i]);
//                if (xDiff[i]>maxXDiff) {
//                    maxXDiff = xDiff[i];
//                }
                maxXDiff += xDiff[i];
                
                yDiff[i] = fabs(ys[i+nOrder]-ys[i]);
//                if (yDiff[i]>maxYDiff) {
//                    maxYDiff = yDiff[i];
//                }
                maxYDiff += yDiff[i];
            }
            
            maxMagDiff = maxMagDiff/ (acThresh - nOrder);
            maxXDiff = maxXDiff/ (acThresh - nOrder);
            maxYDiff = maxYDiff/ (acThresh - nOrder);
            
            printf("\n\nMag Diff: %f\nX Diff: %f\nY Diff: %f\n\n",maxMagDiff,maxXDiff,maxYDiff);
            
            float salience = maxMagDiff;
            
            
            int theFinalTempo = calculateMode(vectorTempos);
        
            [self playSongWithTempo: [NSNumber numberWithInt:theFinalTempo] andSalience:[NSNumber numberWithFloat:salience]];
            
            recalibrate = YES;
            
            //test
//              printf("time = %f\n",elapsed);
//            printf("mags: \n\n");
//            for (int i = 0; i<acThresh; i++) {
//                printf("%f;\n",mags[i]);
//            }
//            printf("xs: \n\n");
//            for (int i = 0; i<acThresh; i++) {
//                printf("%f;\n",xs[i]);
//            }
//            printf("ys: \n\n");
//            for (int i = 0; i<acThresh; i++) {
//                printf("%f;\n",ys[i]);
//            }

        }
        
        acCounter++;
        
        //std::cout << mag/points << ";" << std::endl;
        
        if(points < recalibrate_num){

            recalibrate = YES;
            std::cout << "recalibrate" << std::endl;
        }

    }
    }
    
    else{

    }
}



-(void)findFeatures:(Mat&)image{
    
    //getGray(image, image_next);
    cv::extractChannel(image, image_next, 0);
    cv::goodFeaturesToTrack(image_next, features_next, maxCount, qLevel, minDist);
    
    acCounter = 0;
    tickCountStart = cvGetTickCount();
    
    
}

int roundToNearest5bpm(float tempo){
    
    int rounded = round(tempo / 10.0) * 10;
    return rounded;
}


std::vector<int> calculateAutocorrelation(float values[], float time){
    
    float sum = 0;
    int length = acThresh;
    float autoCorrelation[length];
    
    std::vector<int> thetempos(numPeaks,-1);
    
    for (int i = 0; i<length; i++){
        
        sum = 0;
        
        for (int j = 0; j<length - i; j++){
            
            sum += values[j] * values[j+i];
            
        }
        
        //to remove bias
        //sum *= (1+ i);
        //sum = pow(sum, 2);

        //autoCorrelation[i] = sum/variance;
        autoCorrelation[i]=sum/(length-i);
        
        //printf("%f ",autoCorrelation[i]); 

    }
    
    std::vector<std::pair<float, int>> peaks(numPeaks);
    peaks = findPeaks(autoCorrelation);
    
    double lagTime = time/1000/1000/acThresh;
    
    std::sort(peaks.begin(),peaks.end());
    std::reverse(peaks.begin(), peaks.end());
    
    
    for (int i =0; i<peaks.size(); i++) {
        if (peaks[i].second == -1) break;
        float tempo = scaleTime(peaks[i].second,lagTime);
        
        //printf("lag: %i, peak: %f",peaks[i].second,peaks[i].first);
        printf("%i\n", roundToNearest5bpm(tempo));
        thetempos[i] = roundToNearest5bpm(tempo);
        }
    printf("\n");
    return thetempos;
}


float scaleTime(int lags, float lagTime){
        
    float scaledTime = 60.0/(lags*lagTime);
    
    if (scaledTime<minTemp) {
        while (scaledTime<minTemp) {
            scaledTime = scaledTime*2;
        }
    }
    else if (scaledTime>maxTemp) {
        while (scaledTime>maxTemp) {
            scaledTime = scaledTime/2;
        }
    }
    
    return scaledTime; 
}




std::vector<std::pair<float, int>> findPeaks(float values[]){
    
    //poor man's peak picker
    
    std::vector<std::pair<float, int>> peaks(numPeaks);
    for (int i = 0; i<peaks.size(); i++) {
        peaks[i].second = -1;
    }
    
    
    int length = acThresh;
    int peaksFound = 0;
    
    
    for (int i = peakWidth; i<length-(peakWidth); i++){
        
        bool peak = true;
        for (int j = 1; j<peakWidth; j++) {
            if (!(values[i]>values[i-j] && values[i]>values[i+j])) {
                peak = false;
                break;
            }
        }
        if (peak) {
            
            peaks[peaksFound].first=values[i];
            peaks[peaksFound].second=i;
            peaksFound++;
            
        }
        
        if (peaksFound == numPeaks){
            break;
        }
    }
    
    return peaks;
}


void getGray(const cv::Mat& input, cv::Mat& gray)
{
    const int numChannes = input.channels();
    
    if (numChannes == 4)
    {
        neon_cvtColorBGRA2GRAY(input, gray);
    }
    else if (numChannes == 3)
    {
        cv::cvtColor(input, gray, CV_BGR2GRAY);
    }
    else if (numChannes == 1)
    {
        gray = input;
    }
}



#endif


@end

