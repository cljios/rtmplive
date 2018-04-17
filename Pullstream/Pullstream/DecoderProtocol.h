//
//  DecoderProtocol.h
//  Pullstream
//
//  Created by clj on 16/10/18.
//  Copyright © 2016年 clj. All rights reserved.
//

#ifndef DecoderProtocol_h
#define DecoderProtocol_h
#import "VideoData.h"
@protocol H264DecoderProtocol <NSObject>

- (void)outputVideoData:(VideoData *)videdata;


@end


#endif /* DecoderProtocol_h */
