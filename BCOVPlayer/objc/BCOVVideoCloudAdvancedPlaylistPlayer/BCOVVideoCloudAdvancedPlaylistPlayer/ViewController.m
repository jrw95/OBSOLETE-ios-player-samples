//
//  ViewController.m
//  BCOVVideoCloudAdvancedPlaylistPlayer
//
// Copyright (c) 2014 Brightcove, Inc. All rights reserved.
// License: https://accounts.brightcove.com/en/terms-and-conditions
//

#import "ViewController.h"


// ** Customize Here **
static NSString * const kViewControllerCatalogToken = @"nFCuXstvl910WWpPnCeFlDTNrpXA5mXOO9GPkuTCoLKRyYpPF1ikig..";
static NSString * const kViewControllerPlaylistID = @"3766400043001";

// KVO these two properties of AVPlayerItem will show or hide UIActivityIndicatorView
// When avplayerItem.playbackBufferEmpty == YES && avplayerItem.playbackLikelyToKeepUp == NO, show UIActivityIndicatorView
// When avplayerItem.playbackBufferEmpty == NO && avplayerItem.playbackLikelyToKeepUp == YES, hide UIActivityIndicatorView
static NSString * const kPlaybackBufferEmpty = @"playbackBufferEmpty";
static NSString * const kPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";
static void *kPlaybackBufferEmptyContext = &kPlaybackBufferEmptyContext;
static void *kPlaybackLikelyToKeepUpContext = &kPlaybackLikelyToKeepUpContext;

@interface ViewController ()

@property (nonatomic, strong) BCOVCatalogService *catalogService;
@property (nonatomic, weak) id<BCOVPlaybackSession> currentPlaybackSession;
@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;
@property (nonatomic, weak) IBOutlet UIView *videoContainerView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) id notificationObservingReceipt;

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

- (id)init
{
    self = [super init];
    if (self)
	{
        [self setup];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
	{
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setup];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    self.playbackController.view.frame = self.videoContainerView.bounds;
    self.playbackController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.videoContainerView addSubview:self.playbackController.view];
}

- (void)setup
{
    BCOVVideoCloudAdvancedPlaylistPlayerSDKManager *playbackManager = [BCOVVideoCloudAdvancedPlaylistPlayerSDKManager sharedManager];
    
    
    id<BCOVPlaybackController> playbackController = [playbackManager createPlaybackControllerWithViewStrategy: [self viewStrategyWithFrame:CGRectMake(0, 0, 400, 400)]];
    
    playbackController.delegate = self;
    self.playbackController = playbackController;
    
    // If AVPlayerItemFailedToPlayToEndTimeNotification is sent, AVPlayerItem will be treated as finished playing.
    typeof(self) __weak weakSelf = self;
    self.notificationObservingReceipt = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemFailedToPlayToEndTimeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        
        typeof (self) strongSelf = weakSelf;
        if (note.object == strongSelf.playerItem)
        {
            strongSelf.playerItem = nil;
            [strongSelf.activityIndicator stopAnimating];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"AVPlayer item failded to play to end time" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }
        
    }];

    [self.playbackController setAutoAdvance:YES];
    [self.playbackController setAutoPlay:YES];
    
    
    self.catalogService = [[BCOVCatalogService alloc] initWithToken:kViewControllerCatalogToken];
    [self requestContentFromCatalog];
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

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{
    if ([kBCOVPlaybackSessionLifecycleEventTerminate isEqualToString:lifecycleEvent.eventType]) {
        [self.activityIndicator stopAnimating];
    }
}

- (void)requestContentFromCatalog
{
    [self.catalogService findPlaylistWithPlaylistID:kViewControllerPlaylistID parameters:nil completion:^(BCOVPlaylist *playlist, NSDictionary *jsonResponse, NSError *error) {

        if (playlist)
        {
            [self.playbackController setVideos:playlist.videos];
        }
        else
        {
            NSLog(@"ViewController Debug - Error retrieving playlist: %@", error);
        }
        
    }];
}

- (BCOVPlaybackControllerViewStrategy)videoStillViewStrategyWithFrame
{
    return [^ UIView * (UIView *videoView, id<BCOVPlaybackController> playbackController) {
        
        // Returns a view which covers `videoView` with a UIImageView
        // whose background is black and which presents the video still from
        // each video as it becomes the current video.
        VideoStillView *stillView = [[VideoStillView alloc] initWithVideoView:videoView];
        VideoStillViewMediator *stillViewMediator = [[VideoStillViewMediator alloc] initWithVideoStillView:stillView];
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
    BCOVVideoCloudAdvancedPlaylistPlayerSDKManager *manager = [BCOVVideoCloudAdvancedPlaylistPlayerSDKManager sharedManager];
    
    // In this example, we use the defaultControlsViewStrategy. In real app, you
    // wouldn't be using this.  You would add your controls and container view
    // in the composedViewStrategy block below.
    BCOVPlaybackControllerViewStrategy stillViewStrategy = [self videoStillViewStrategyWithFrame];
    BCOVPlaybackControllerViewStrategy defaultControlsViewStrategy = [manager defaultControlsViewStrategy];
    
    BCOVPlaybackControllerViewStrategy composedViewStrategy = ^ UIView * (UIView *videoView, id<BCOVPlaybackController> playbackController) {
        
        videoView.frame = frame;
        
        UIView *viewWithStill = stillViewStrategy(videoView, playbackController);
        UIView *viewWithControls = defaultControlsViewStrategy(viewWithStill, playbackController); //Replace this with your own container view.
        
        return viewWithControls;
        
    };
    
    return [composedViewStrategy copy];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kPlaybackBufferEmptyContext || context == kPlaybackLikelyToKeepUpContext)
    {
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
