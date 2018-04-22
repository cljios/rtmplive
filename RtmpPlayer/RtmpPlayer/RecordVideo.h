//
//  RecordVideo.h
//  RtmpPlayer
//
//  Created by clj on 16/8/17.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "H264Encoder.h"
@interface RecordVideo : NSObject
@property (strong, nonatomic) H264Encoder *h264Encoder;
@property (nonatomic,copy) NSString* rtmpUrl;//rtmp服务器流地址

- (void)setLayerDisplay:(UIView *)view width:(int32_t)width height:(int32_t)height;
@end
