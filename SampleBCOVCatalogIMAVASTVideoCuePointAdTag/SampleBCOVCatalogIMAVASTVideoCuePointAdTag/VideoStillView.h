//
//  VideoStillView.h
//  SampleBCOVIMA
//
//  Created by Erik Price on 2014 04 09.
//  Copyright (c) 2014 Brightcove. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "BCOVPlayerSDK.h"

/// UIView for presenting a video still over a BCOVPlaybackController's video
/// view. This class is intended to be paired with a VideoStillViewMediator.
@interface VideoStillView : UIView

/// Initializes an instance of VideoStillView, adding `videoView` as a subview.
/// As with most UIView methods, this should only be called from the main
/// thread.
- (id)initWithVideoView:(UIView *)videoView;

@end


/// An implementation of BCOVDelegatingSessionConsumerDelegate which dismisses
/// a video still image when playback begins. Once dismissed, it cannot be
/// recovered. A VideoStillViewMediator should be set as the delegate of a
/// BCOVDelegatingSessionConsumer that has been added as a session consumer of
/// a BCOVPlaybackController.
///
/// For each playback session, the mediator will set the appropriate image
/// as the video still (if a video still URL can be found on each session's
/// BCOVVideo), and will dismiss the video still once playback begins.
///
/// (Note that there is little reason to use a VideoStillViewMediator if
/// `BCOVPlaybackController.autoPlay` is enabled.)
@interface VideoStillViewMediator : NSObject <BCOVDelegatingSessionConsumerDelegate>

/// Initializes the mediator with `videoStillView`. The `videoStillView` is
/// weakly referenced by the mediator.
- (id)initWithVideoStillView:(VideoStillView *)videoStillView;

/// Delay duration in seconds before the video still is dismissed after
/// playback begins.
@property (nonatomic) NSTimeInterval dismissalDelay;

@end