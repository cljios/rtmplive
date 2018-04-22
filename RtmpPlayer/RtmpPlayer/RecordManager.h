//
//  RecordManager.h
//  RtmpPlayer
//
//  Created by clj on 16/9/1.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RecordManager : NSObject

+ (id)shareManager;
- (BOOL)setupProfile;
- (void)writeRecordData:(NSData *)data;
- (BOOL)startRtmpConnect:(NSString *)urlString;

- (void)firstFrameAudioData;
- (void)send_rtmp_audio_spec:(NSData *)spec_buf andLength:(uint32_t) spec_len;
- (void)send_rtmp_audio:(NSData *)buf andLength:(uint32_t)len;
- (void)send_video_sps_pps:(NSData *)sps andSpsLength:(uint32_t)sps_len andPPs:(NSData*)pps andPPsLength:(uint32_t)pps_len;
- (void)send_rtmp_video:(NSData *)buf andLength:(uint32_t)length;
@end
