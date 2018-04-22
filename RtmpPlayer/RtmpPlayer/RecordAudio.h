//
//  RecordAudio.h
//  RtmpPlayer
//
//  Created by clj on 16/9/1.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <librtmp/rtmp.h>
@interface RecordAudio : NSObject

- (void) start;
- (void)sendSpec;
@end
