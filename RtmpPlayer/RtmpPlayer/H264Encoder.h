//
//  H264Encoder.h
//  RtmpPlayer
//
//  Created by clj on 16/8/17.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol VideoDataDelagate <NSObject>

- (void)naluSlice:(id)naluData;
- (void)spsData:(NSData *)spsData ppsData:(NSData *)ppsData;
- (void)fileNaludata:(NSData *)data iskeyF:(BOOL) iskey;

@end

@interface H264Encoder : NSObject
@property (assign,nonatomic) NSInteger frameNum;
@property (weak ,nonatomic) id delegate;
- (void)videoEncode:(CMSampleBufferRef )sampleBuffer;
- (void)initEncodeWidth:(int32_t)width height:(int32_t)height;
@end
