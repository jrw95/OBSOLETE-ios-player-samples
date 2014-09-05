//
//  VideoStillView.m
//  SampleBCOVIMA
//
//  Created by Erik Price on 2014 04 09.
//  Copyright (c) 2014 Brightcove. All rights reserved.
//

#import "VideoStillView.h"


@interface VideoStillView ()

// We can weakly reference the `imageView` because it will be retained when we
// add it as a subview.
@property (nonatomic, weak) UIImageView *imageView;
@property (nonatomic, strong) UIColor *imageViewBackgroundColor;

@end


@implementation VideoStillView

// None of the methods in this class have been designed to be called safely
// from a non-main thread.

- (id)initWithVideoView:(UIView *)videoView
{
    if (self = [super init])
    {
        videoView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
        _imageViewBackgroundColor = [UIColor blackColor];
        self.frame = videoView.bounds;
        [self addSubview:videoView];
        
        [self addImageView];
    }
    
    return self;
}

- (void)setVideoStillImage:(UIImage *)videoStillImage
{
    if (!self.imageView)
    {
        [self addImageView];
    }
    
    self.imageView.image = videoStillImage;
}

- (void)addImageView
{
    [self dismiss];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.backgroundColor = self.imageViewBackgroundColor;
    [self addSubview:imageView];
    self.imageView = imageView;
}

- (void)dismiss
{
    // Once the video still has been dismissed, it cannot be recovered.
    self.imageView.image = nil;
    [self.imageView removeFromSuperview];
    self.imageView = nil;
}

@end




@interface VideoStillViewMediator ()

@property (nonatomic, weak) VideoStillView *videoStillView;
@property (nonatomic) BOOL loaded;

@end

@implementation VideoStillViewMediator

- (id)initWithVideoStillView:(VideoStillView *)videoStillView
{
    if (self = [super init])
    {
        _videoStillView = videoStillView;
        _dismissalDelay = 0.0f;
    }
    
    return self;
}

// Note that BCOVDelegatingSessionConsumerDelegate methods are always called
// on the main thread, so it is safe to call VideoStillView's methods.

- (void)playbackConsumer:(id<BCOVPlaybackSessionConsumer>)consumer didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    BOOL playing = session.player.rate > 0.01;
    if (!playing)
    {
        [self loadVideoStillForSession:session];
    }
}

- (void)playbackConsumer:(id<BCOVPlaybackSessionConsumer>)consumer playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{
    if (self.loaded && [kBCOVPlaybackSessionLifecycleEventPlay isEqualToString:lifecycleEvent.eventType])
    {
        // The `loaded` ivar protects against multiple dismissals during a
        // single session.
        self.loaded = NO;
        [self dismissVideoStillView];
    }
}

- (void)loadVideoStillForSession:(id<BCOVPlaybackSession>)session
{
    self.loaded = YES;
    VideoStillView *videoStillView = self.videoStillView;
    [videoStillView addImageView];
    
    NSString *urlStr = session.video.properties[kBCOVCatalogJSONKeyVideoStillUrl];
    if (urlStr)
    {
        NSURL *url = [NSURL URLWithString:urlStr];
        if (url)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                NSData *imageData = [NSData dataWithContentsOfURL:url];
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    BOOL playing = session.player.rate > 0.01;
                    if (!playing)
                    {
                        videoStillView.videoStillImage = [UIImage imageWithData:imageData];
                    }
                    
                });
                
            });
        }
    }
}

- (void)dismissVideoStillView
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.dismissalDelay * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        
        [self.videoStillView dismiss];
        
    });
}

@end