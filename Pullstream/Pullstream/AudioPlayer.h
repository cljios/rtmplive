//
//  AudioPlayer.h
//  Pullstream
//
//  Created by clj on 16/10/23.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
typedef void (^KxAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@interface AudioPlayer : NSObject
@property (readwrite, copy) KxAudioManagerOutputBlock outputBlock;

- (void) start;
- (void) stop;
- (void) processAudio: (AudioBufferList*) bufferList;

@end
