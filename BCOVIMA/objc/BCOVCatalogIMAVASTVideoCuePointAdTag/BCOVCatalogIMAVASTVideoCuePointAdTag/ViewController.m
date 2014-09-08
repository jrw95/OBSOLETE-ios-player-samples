//
//  ViewController.m
//  BCOVCatalogIMAVASTVideoCuePointAdTag
//
//  Copyright (c) 2014 Brightcove. All rights reserved.
//

#import "ViewController.h"


NSString *const kSampleAppAdTagUrl_1 = @"http://pubads.g.doubleclick.net/gampad/ads?sz=400x300&iu=%2F6062%2Fhanna_MA_group%2Fvideo_comp_app&ciu_szs=&impl=s&gdfp_req=1&env=vp&output=xml_vast2&unviewed_position_start=1&m_ast=vast&url=[referrer_url]&correlator=[timestamp]";

NSString *const kSampleAppAdTagUrl_2 = @"http://pubads.g.doubleclick.net/gampad/ads?sz=400x300&iu=%2F6062%2Fhanna_MA_group%2Fwrapper_with_comp&ciu_szs=728x90&impl=s&gdfp_req=1&env=vp&output=xml_vast2&unviewed_position_start=1&m_ast=vast&url=[referrer_url]&correlator=[timestamp]";

NSString *const kSampleAppAdTagUrl_3 = @"http://googleads.g.doubleclick.net/pagead/ads?client=ca-video-afvtest&ad_type=video";

NSString *const kSampleAppAdTagUrl_4 = @"http://pubads.g.doubleclick.net/gampad/ads?sz=400x300&iu=%2F6062%2Fhanna_MA_group%2Fvideo_comp_app&ciu_szs=&impl=s&gdfp_req=1&env=vp&output=xml_vast2&unviewed_position_start=1&m_ast=vast";

// Replace this value with your own API token value
NSString *kSampleAppPublisherApiToken = @"nFCuXstvl910WWpPnCeFlDTNrpXA5mXOO9GPkuTCoLKRyYpPF1ikig..";

// Replace this value with your own Playlist ID
NSString * const kSampleAppPlaylistId = @"3766400042001";

NSString * const kSampleAppIMAPublisherID = @"insertyourpidhere";
NSString * const kSampleAppIMALanguage = @"en";

NSString *kBrightcoveApiUrl = @"http://api.brightcove.com/services/library";

// KVO these two properties of AVPlayerItem will show or hide UIActivityIndicatorView
// When avplayerItem.playbackBufferEmpty == YES && avplayerItem.playbackLikelyToKeepUp == NO, show UIActivityIndicatorView
// When avplayerItem.playbackBufferEmpty == NO && avplayerItem.playbackLikelyToKeepUp == YES, hide UIActivityIndicatorView
static NSString * const kPlaybackBufferEmpty = @"playbackBufferEmpty";
static NSString * const kPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";
static void *kPlaybackBufferEmptyContext = &kPlaybackBufferEmptyContext;
static void *kPlaybackLikelyToKeepUpContext = &kPlaybackLikelyToKeepUpContext;


@interface BCOVCuePointCollection(BCOVIMAVAST)

- (NSUInteger)adsCount;

@end

@implementation BCOVCuePointCollection(BCOVIMAVAST)

- (NSUInteger)adsCount
{
    NSUInteger count = 0;
    NSArray *cuePoints = [self array];
    for (BCOVCuePoint *cuePoint in cuePoints) {
        if ([kBCOVIMACuePointTypeAd isEqualToString:cuePoint.type]) {
            count++;
        }
    }
    return count;
}

@end


@interface ViewController () <IMAWebOpenerDelegate>

@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;
@property (nonatomic, strong) BCOVCatalogService *catalog;
@property (nonatomic, strong) BCOVMediaRequestFactory *mediaRequestFactory;
@property (nonatomic, weak) id<BCOVPlaybackSession> currentPlaybackSession;
@property (weak, nonatomic) IBOutlet UIView *videoContainer;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) id notificationObservingReceipt;
@property (nonatomic, assign) BOOL adIsPlaying;
@property (nonatomic, assign) BOOL isBrowserOpen;

@end


@implementation ViewController

- (void)dealloc
{
    if (_playerItem)
    {
        [_playerItem removeObserver:self forKeyPath:kPlaybackBufferEmpty context:kPlaybackBufferEmptyContext];
        [_playerItem removeObserver:self forKeyPath:kPlaybackLikelyToKeepUp context:kPlaybackLikelyToKeepUpContext];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:_notificationObservingReceipt];
}

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
    
    self.mediaRequestFactory = [[BCOVMediaRequestFactory alloc] initWithToken:kSampleAppPublisherApiToken baseURLString:kBrightcoveApiUrl];
    self.catalog = [[BCOVCatalogService alloc] initWithMediaRequestFactory:self.mediaRequestFactory];
    BCOVPlayerSDKManager *sdkManager = [BCOVPlayerSDKManager sharedManager];
    
    IMASettings *imaSettings = [[IMASettings alloc] init];
    imaSettings.ppid = kSampleAppIMAPublisherID;
    imaSettings.language = kSampleAppIMALanguage;
    
    IMAAdsRenderingSettings *renderSettings = [[IMAAdsRenderingSettings alloc] init];
    renderSettings.webOpenerPresentingController = self;
    renderSettings.webOpenerDelegate = self;
    
    BCOVIMASessionProviderOptions *sessionProviderOption = [BCOVIMASessionProviderOptions VASTOptions];
    
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
        if (note.object == strongSelf.playerItem)
        {
            strongSelf.playerItem = nil;
            [strongSelf.activityIndicator stopAnimating];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"AVPlayer item failded to play to end time" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
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
    else if ([kBCOVPlaybackSessionLifecycleEventTerminate isEqualToString:lifecycleEvent.eventType])
    {
        [self.activityIndicator stopAnimating];
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
    self.playerItem = session.player.currentItem;
    NSLog(@"ViewController Debug - Advanced to new session.");
}

- (void)setPlayerItem:(AVPlayerItem *)playerItem
{
    if (_playerItem)
    {
        [_playerItem removeObserver:self forKeyPath:kPlaybackBufferEmpty context:kPlaybackBufferEmptyContext];
        [_playerItem removeObserver:self forKeyPath:kPlaybackLikelyToKeepUp context:kPlaybackLikelyToKeepUpContext];
    }
    
    _playerItem = playerItem;
    
    [_playerItem addObserver:self forKeyPath:kPlaybackBufferEmpty options:NSKeyValueObservingOptionNew context:kPlaybackBufferEmptyContext];
    [_playerItem addObserver:self forKeyPath:kPlaybackLikelyToKeepUp options:NSKeyValueObservingOptionNew context:kPlaybackLikelyToKeepUpContext];
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
                         
                         NSUInteger adsCount = [mutableVideo.cuePoints adsCount];
                         
                         if (adsCount == 0)
                         {
                             mutableVideo.cuePoints = [[BCOVCuePointCollection alloc] initWithArray:@[
                                  [[BCOVCuePoint alloc] initWithType:kBCOVIMACuePointTypeAd position:kBCOVCuePointPositionTypeBefore properties:@{ kBCOVIMAAdTag : kSampleAppAdTagUrl_2 }],
                                  [[BCOVCuePoint alloc] initWithType:kBCOVIMACuePointTypeAd position:CMTimeMake(10,1) properties:@{ kBCOVIMAAdTag : kSampleAppAdTagUrl_1 }],
                                  [[BCOVCuePoint alloc] initWithType:kBCOVIMACuePointTypeAd position:kBCOVCuePointPositionTypeAfter properties:@{ kBCOVIMAAdTag : kSampleAppAdTagUrl_2 }],
                                  ]];
                             
                         } else
                         {
                             
                             NSMutableArray *newCuePoints = [NSMutableArray arrayWithCapacity:mutableVideo.cuePoints.count];
                             __block NSMutableDictionary *cuePointProperties = nil;
                             
                             for (BCOVCuePoint *cuePoint in mutableVideo.cuePoints)
                             {
                                 
                                 BCOVCuePoint *newCuePoint = nil;
                                 
                                 if ([kBCOVIMACuePointTypeAd isEqualToString:cuePoint.type])
                                 {
                                 
                                     if ([cuePoint.properties[@"name"] isEqualToString:@"Pre-roll" ])
                                     {
                                         newCuePoint = [cuePoint update:^(id<BCOVMutableCuePoint> mutableCuePoint) {
                                             
                                             cuePointProperties = [[NSMutableDictionary alloc] initWithDictionary:mutableCuePoint.properties];
                                             mutableCuePoint.position = kBCOVCuePointPositionTypeBefore;
                                             cuePointProperties[kBCOVIMAAdTag] = kSampleAppAdTagUrl_3;
                                             mutableCuePoint.properties = cuePointProperties;
                                             
                                         }];
                                         
                                         [newCuePoints addObject: newCuePoint];
                                         
                                     }
                                     else if ([cuePoint.properties[@"name"] isEqualToString:@"Post-roll" ])
                                     {
                                         
                                         newCuePoint = [cuePoint update:^(id<BCOVMutableCuePoint> mutableCuePoint) {
                                             
                                             cuePointProperties = [[NSMutableDictionary alloc] initWithDictionary:mutableCuePoint.properties];
                                             mutableCuePoint.position = kBCOVCuePointPositionTypeAfter;
                                             cuePointProperties[kBCOVIMAAdTag] = kSampleAppAdTagUrl_2;
                                             mutableCuePoint.properties = cuePointProperties;
                                             
                                         }];
                                         
                                         [newCuePoints addObject: newCuePoint];
                                         
                                     }
                                     else
                                     {
                                         
                                         newCuePoint = [cuePoint update:^(id<BCOVMutableCuePoint> mutableCuePoint) {
                                             
                                             cuePointProperties = [[NSMutableDictionary alloc] initWithDictionary:mutableCuePoint.properties];
                                             cuePointProperties[kBCOVIMAAdTag] = kSampleAppAdTagUrl_4;
                                             mutableCuePoint.properties = cuePointProperties;
                                             
                                         }];
                                         
                                         [newCuePoints addObject: newCuePoint];
                                         
                                     }
                                     
                                 }
                                 else
                                 {
                                     [newCuePoints addObject:cuePoint];
                                 }
                                 
                                 mutableVideo.cuePoints = [BCOVCuePointCollection collectionWithArray:newCuePoints];
                                 
                             }
                         }
                         
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

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kPlaybackBufferEmptyContext || context == kPlaybackLikelyToKeepUpContext)
    {
        NSLog(@"BE = %d", self.playerItem.playbackBufferEmpty);
        NSLog(@"keep = %d", self.playerItem.playbackBufferEmpty);
        if (self.playerItem.playbackBufferEmpty == YES && self.playerItem.playbackLikelyToKeepUp == NO )
        {
            [self.activityIndicator startAnimating];
        }
        else if (self.playerItem.playbackBufferEmpty == NO && self.playerItem.playbackLikelyToKeepUp == YES )
        {
            [self.activityIndicator stopAnimating];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
