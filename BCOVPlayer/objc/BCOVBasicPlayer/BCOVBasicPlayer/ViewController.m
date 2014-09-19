//
//  ViewController.m
//  BCOVBasicPlayer
//
// Copyright (c) 2014 Brightcove, Inc. All rights reserved.
// License: https://accounts.brightcove.com/en/terms-and-conditions
//

#import "ViewController.h"


// ** Customize Here **
static NSString * const kViewControllerCatalogToken = @"nFCuXstvl910WWpPnCeFlDTNrpXA5mXOO9GPkuTCoLKRyYpPF1ikig..";
static NSString * const kViewControllerPlaylistID = @"3766400043001";


@interface ViewController ()

@property (nonatomic, strong) BCOVCatalogService *catalogService;
@property (nonatomic, weak) id<BCOVPlaybackSession> currentPlaybackSession;
@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;
@property (nonatomic, weak) IBOutlet UIView *videoContainerView;

@end


@implementation ViewController

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
    // add the playback controller
    self.playbackController = [[BCOVPlayerSDKManager sharedManager] createPlaybackControllerWithViewStrategy:[self viewStrategy]];
    self.playbackController.view.frame = self.view.bounds;
    // create a playback controller delegate
    self.playbackController.delegate = self;
    
    [self.playbackController setAutoAdvance:YES];
    [self.playbackController setAutoPlay:YES];
    
    
    self.catalogService = [[BCOVCatalogService alloc] initWithToken:kViewControllerCatalogToken];
    [self requestContentFromCatalog];

}

- (id)viewStrategy
{
    // Most apps can create a playback controller with a `nil` view strategy,
    // but for the purposes of this demo we use the stock controls.
    return [[BCOVPlayerSDKManager sharedManager] defaultControlsViewStrategy];
    }

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    self.currentPlaybackSession = session;
    NSLog(@"ViewController Debug - Advanced to new session.");
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
