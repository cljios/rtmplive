//
//  MediaManager.h
//  Pullstream
//
//  Created by clj on 16/10/21.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <pthread.h>
#import "H264Decoder.h"
#import "FAACDecoder.h"
#import "AudioPlayer.h"
@interface MediaManager : NSObject

- (BOOL)profileAudioSession;
- (BOOL)connectRtmpSever:(char *)url;
- (void)rtmpDisconnect;
- (void)decodeFrame;
- (MediaFrame *)presentFrame;
- (MediaFrame *)getAudioFrame;
- (NSArray *)presentVideoFrame;
- (MediaFrame *)playAudioFrame;
@end
