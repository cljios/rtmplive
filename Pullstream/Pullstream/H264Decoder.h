//
//  H264Decoder.h
//  Pullstream
//
//  Created by clj on 16/9/13.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import "SYStruct.h"
#import "MediaFrame.h"

@interface H264Decoder : NSObject
-(void)decodeVideoFrameData:(VideoCompressData*)vpkt YUVData:(MediaFrame **)videoModel;
-(BOOL)initH264DecoderWithSPS:(char *)sps spslen:(uint32_t)spslen pps:(char *)pps ppslen:(uint32_t)ppslen;
@end
