//
//  AudioUnitRecordAudio.h
//  RtmpPlayer
//
//  Created by clj on 16/9/24.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>

@protocol PCMDelegate <NSObject>

- (void)pcmData:(char *)data datalen:(uint32_t)len inputFormat:(        AudioStreamBasicDescription)audioFormat;

@end
@interface AudioUnitRecordAudio : NSObject
@property (nonatomic,weak)id <PCMDelegate>delegate;
- (void) start;

@end
