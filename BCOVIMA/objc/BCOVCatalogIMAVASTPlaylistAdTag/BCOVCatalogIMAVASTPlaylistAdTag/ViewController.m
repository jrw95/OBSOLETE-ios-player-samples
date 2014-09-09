//
//  ViewController.m
//  BCOVCatalogIMAVASTPlaylistAdTag
//
//  Copyright (c) 2014 Brightcove. All rights reserved.
//

#import "ViewController.h"


NSString *const kSampleAppAdTag_Wrapper = @"http://pubads.g.doubleclick.net/gampad/ads?sz=400x300&iu=%2F6062%2Fhanna_MA_group%2Fwrapper_with_comp&ciu_szs=728x90&impl=s&gdfp_req=1&env=vp&output=xml_vast2&unviewed_position_start=1&m_ast=vast";

// Replace this value with your own API token value
NSString * const kSampleAppApiToken = @"nFCuXstvl910WWpPnCeFlDTNrpXA5mXOO9GPkuTCoLKRyYpPF1ikig..";

// Replace this value with your own Playlist ID value
NSString * const kSampleAppPlaylistId = @"3766400043001";

NSString * const kBrightcoveApiUrl = @"http://api.brightcove.com/services/library";

NSString * const kSampleAppIMAPublisherID = @"insertyourpidhere";
NSString * const kSampleAppIMALanguage = @"en";


@interface ViewController () <IMAWebOpenerDelegate>

@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;
@property (nonatomic, strong) BCOVCatalogService *catalog;
@property (nonatomic, strong) BCOVMediaRequestFactory *mediaRequestFactory;
@property (nonatomic, weak) id<BCOVPlaybackSession> currentPlaybackSession;
@property (weak, nonatomic) IBOutlet UIView *videoContainer;
@property (nonatomic, assign) BOOL adIsPlaying;
@property (nonatomic, assign) BOOL isBrowserOpen;

@end


@implementation ViewController


#pragma mark Initialization methods

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setup];
}

- (void)setup
{
    self.adIsPlaying = NO;
    self.isBrowserOpen = NO;
    
    self.mediaRequestFactory = [[BCOVMediaRequestFactory alloc] initWithToken:kSampleAppApiToken baseURLString:kBrightcoveApiUrl];
    self.catalog = [[BCOVCatalogService alloc] initWithMediaRequestFactory:self.mediaRequestFactory];
    BCOVPlayerSDKManager *sdkManager = [BCOVPlayerSDKManager sharedManager];
    
    IMASettings *imaSettings = [[IMASettings alloc] init];
    imaSettings.ppid = kSampleAppIMAPublisherID;
    imaSettings.language = kSampleAppIMALanguage;
    
    IMAAdsRenderingSettings *renderSettings = [[IMAAdsRenderingSettings alloc] init];
    renderSettings.webOpenerPresentingController = self;
    renderSettings.webOpenerDelegate = self;
    
    BCOVIMASessionProviderOptions *sessionProviderOption = [BCOVIMASessionProviderOptions VASTOptions];
    sessionProviderOption.adsRequestPolicy = [BCOVIMAAdsRequestPolicy adsRequestPolicyFromCuePointPropertiesWithAdTag:kSampleAppAdTag_Wrapper adsCuePointProgressPolicy:nil];
    
    id<BCOVPlaybackSessionProvider> playbackSessionProvider = [sdkManager createIMASessionProviderWithSettings:imaSettings adsRenderingSettings:renderSettings upstreamSessionProvider:nil options:sessionProviderOption];
    id<BCOVPlaybackController> playbackController = [sdkManager createPlaybackControllerWithSessionProvider:playbackSessionProvider viewStrategy:[self viewStrategyWithFrame:CGRectMake(0, 0, 400, 400)]];
    
    playbackController.delegate = self;
    _playbackController = playbackController;
    
    ViewController * __weak weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:self queue:nil usingBlock:^(NSNotification *note) {
        
        ViewController *strongSelf = weakSelf;
        
        if (strongSelf.adIsPlaying && !strongSelf.isBrowserOpen)
        {
            [strongSelf.playbackController resumeAd];
        }
        
    }];
    
    [self requestContentFromCatalog];
    
    self.playbackController.autoAdvance = YES;
    self.playbackController.autoPlay = YES;
    
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{

    NSLog(@"Lifecycle Event Type: %@", lifecycleEvent.eventType);

    if ([kBCOVIMALifecycleEventAdsLoaderLoaded isEqualToString:lifecycleEvent.eventType])
    {
        NSLog(@"ViewController Debug - Ads loaded.");
    }
    else if ([kBCOVIMALifecycleEventAdsManagerDidReceiveAdEvent isEqualToString:lifecycleEvent.eventType])
    {
        IMAAdEvent *adEvent = lifecycleEvent.properties[@"adEvent"];
        
        switch (adEvent.type)
        {
            case kIMAAdEvent_STARTED:
                NSLog(@"ViewController Debug - Ad Started.");
                self.adIsPlaying = YES;
                break;
            case kIMAAdEvent_COMPLETE:
                NSLog(@"ViewController Debug - Ad Completed.");
                self.adIsPlaying = NO;
                break;
            case kIMAAdEvent_ALL_ADS_COMPLETED:
                NSLog(@"ViewController Debug - All ads completed.");
                break;
            default:
                break;
        }
        
    }

}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.playbackController.view.frame = self.videoContainer.bounds;
    self.playbackController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.videoContainer addSubview:self.playbackController.view];

}

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    self.currentPlaybackSession = session;
    NSLog(@"ViewController Debug - Advanced to new session.");
}

- (void)requestContentFromCatalog
{
    
    [self.catalog
     findPlaylistWithPlaylistID:kSampleAppPlaylistId parameters:nil
     completion:^(BCOVPlaylist *playlist, NSDictionary *jsonResponse, NSError *error) {
         
         if(playlist){
             
             BCOVPlaylist *updatedPlaylist = [playlist update:^(id<BCOVMutablePlaylist> mutablePlaylist) {
                 
                 NSMutableArray *newVideos = [NSMutableArray arrayWithCapacity:mutablePlaylist.videos.count];
                 
                 [mutablePlaylist.videos enumerateObjectsUsingBlock:^(BCOVVideo *video, NSUInteger idx, BOOL *stop) {
                     
                     // Update each video to add the ad tag URL.
                     BCOVVideo *updatedVideo = [video update:^(id<BCOVMutableVideo> mutableVideo) {
                         
                         mutableVideo.cuePoints = [[BCOVCuePointCollection alloc] initWithArray:@[
                              [[BCOVCuePoint alloc] initWithType:kBCOVIMACuePointTypeAd position:CMTimeMake(5,1) properties:@{ @"url" : @"www.brov.com", @"correlator": @"5", @"pod": @"1" }],
                              [[BCOVCuePoint alloc] initWithType:kBCOVIMACuePointTypeAd position:CMTimeMake(25,1) properties:@{ @"url" : @"www.after.com", @"correlator": @"25", @"pod": @"2" }],
                              [[BCOVCuePoint alloc] initWithType:kBCOVIMACuePointTypeAd position:CMTimeMake(45,1) properties:@{ @"url" : @"www.brovBrov.com", @"correlator": @"45", @"pod": @"3" }],
                              ]];
                         
                     }];
                     
                     [newVideos addObject:updatedVideo];
                 }];
                 
                 mutablePlaylist.videos = newVideos;
                 
             }];
             
             [self.playbackController setVideos:updatedPlaylist.videos];
             
         }
     }];
    
}

- (void)willOpenInAppBrowser
{
    self.isBrowserOpen = YES;
}

- (void)willCloseInAppBrowser
{
    self.isBrowserOpen = NO;
}

- (BCOVPlaybackControllerViewStrategy)videoStillViewStrategyWithFrame
{
    return [^ UIView * (UIView *videoView, id<BCOVPlaybackController> playbackController) {
        
        // Returns a view which covers `videoView` with a UIImageView
        // whose background is black and which presents the video still from
        // each video as it becomes the current video.
        VideoStillView *stillView = [[VideoStillView alloc] initWithVideoView:videoView];
        VideoStillViewMediator *stillViewMediator = [[VideoStillViewMediator alloc] initWithVideoStillView:stillView];
        // The Google Ads SDK for IMA does not play prerolls instantly when
        // the AVPlayer starts playing. Delaying the dismissal of the video
        // still for a second prevents the first video frame from "flashing"
        // briefly when this happens.
        stillViewMediator.dismissalDelay = 1.f;
        
        // (You should save `consumer` to an instance variable if you will need
        // to remove it from the playback controller's session consumers.)
        BCOVDelegatingSessionConsumer *consumer = [[BCOVDelegatingSessionConsumer alloc] initWithDelegate:stillViewMediator];
        [playbackController addSessionConsumer:consumer];
        
        return stillView;
        
    } copy];
}

- (BCOVPlaybackControllerViewStrategy)viewStrategyWithFrame:(CGRect)frame
{
    BCOVPlayerSDKManager *manager = [BCOVPlayerSDKManager sharedManager];
    
    // In this example, we use the defaultControlsViewStrategy. In real app, you
    // wouldn't be using this.  You would add your controls and container view
    // in the composedViewStrategy block below.
    BCOVPlaybackControllerViewStrategy stillViewStrategy = [self videoStillViewStrategyWithFrame];
    BCOVPlaybackControllerViewStrategy defaultControlsViewStrategy = [manager defaultControlsViewStrategy];
    BCOVPlaybackControllerViewStrategy imaViewStrategy = [manager BCOVIMAAdViewStrategy];
    
    // We create a composed view strategy using the defaultControlsViewStrategy
    // and the BCOVIMAAdViewStrategy.  The purpose of this block is to ensure
    // that the ads appear above above the controls so that we don't need to
    // implement any logic to show and hide the controls.  This should be customized
    // how you see fit.
    // This block is not executed until the playbackController.view property is
    // accessed, even though it is an initialization property. You can
    // use the playbackController property to add an object as a session consumer.
    BCOVPlaybackControllerViewStrategy composedViewStrategy = ^ UIView * (UIView *videoView, id<BCOVPlaybackController> playbackController) {
        
        videoView.frame = frame;
        
        UIView *viewWithStill = stillViewStrategy(videoView, playbackController);
        UIView *viewWithControls = defaultControlsViewStrategy(viewWithStill, playbackController); //Replace this with your own container view.
        UIView *viewWithAdsAndControls = imaViewStrategy(viewWithControls, playbackController);
        
        return viewWithAdsAndControls;
        
    };
    
    return [composedViewStrategy copy];
}

@end
