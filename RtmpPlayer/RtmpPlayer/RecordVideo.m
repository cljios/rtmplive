//
//  RecordVideo.m
//  RtmpPlayer
//
//  Created by clj on 16/8/17.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "RecordVideo.h"
#import "H264Encoder.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "RecordManager.h"

@interface RecordVideo () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t aQueue;
}

@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureConnection *connection;

@end

@implementation RecordVideo

- (instancetype)init{

    if (self = [super init]) {

        self.h264Encoder = [H264Encoder new];
        self.h264Encoder.delegate = self;
        [self setupVideoSession];

    }
    return self;

}

- (BOOL)setupVideoSession{

    
    NSError *error = nil;
    
    // Create the self.session
    
    self.self.session = [[AVCaptureSession alloc] init];
    
    [self.session beginConfiguration];
    
    // Configure the self.session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    
    self.session.sessionPreset = AVCaptureSessionPreset640x480;

    // Find a suitable AVCaptureDevice
    
    NSArray *arr   = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDevice *device = arr[1];
        
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if (!input) {
        // Handling the error appropriately.
    }
    [self.session addInput:input];
    
    // Create a VideoDataOutput and add it to the self.session
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init ];
//    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
//
//    
//    NSNumber* val = [NSNumber
//                         numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    
    NSNumber* val = [NSNumber
                     numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    output.videoSettings = videoSettings;
    [self.session addOutput:output];
    
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
   
    [self.session commitConfiguration];
    

    NSLog(@"cameraDevice.activeFormat.videoSupportedFrameRateRanges IS %@",[device.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0]);
    
    if ([device lockForConfiguration:&error]) {
       
        device.activeVideoMinFrameDuration = CMTimeMake(1, 25);
        
        [device setActiveVideoMaxFrameDuration:CMTimeMake(1,25)];
        
        [device unlockForConfiguration];
    }
    
    // Start the self.session running to start the flow of data
    
    self.connection = [output connectionWithMediaType:AVMediaTypeVideo];
    
    [self setRelativeVideoOrientation:self.connection];
    
    return YES;

}
- (void)setLayerDisplay:(UIView *)view width:(int32_t)width height:(int32_t)height{
    
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    previewLayer.frame = view.bounds;
    [view.layer addSublayer:previewLayer];
    [self.session startRunning];
    [self.h264Encoder initEncodeWidth:width height:height];
}

- (void)setRelativeVideoOrientation:(AVCaptureConnection *)connection{
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
    
}
// Delegate routine that is called when a sample buffer was written

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    if (sampleBuffer) {
        [self.h264Encoder videoEncode:sampleBuffer];
    }
    
}

#pragma mark 编码完成数据回调

- (void)fileNaludata:(NSData *)data iskeyF:(BOOL) iskey{
    
//    unsigned char *nalu = (unsigned char *)[data bytes];
    [[RecordManager shareManager] send_rtmp_video:data andLength:(uint32_t)data.length];
    
}
- (void)spsData:(NSData *)spsData ppsData:(NSData *)ppsData{
    
//    unsigned char *sps = (unsigned char *)[spsData bytes];
//    unsigned char *pps = (unsigned char *)[ppsData bytes];

    [[RecordManager shareManager] send_video_sps_pps:spsData andSpsLength:(uint32_t)spsData.length andPPs:ppsData andPPsLength:(uint32_t)ppsData.length];
    
}

@end
