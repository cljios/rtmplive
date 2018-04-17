//
//  AudioCompressData.h
//  Pullstream
//
//  Created by clj on 16/10/22.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioCompressData : NSObject
@property (nonatomic,assign) double timeStamp;
@property (nonatomic,assign) char*buffer;
@property (nonatomic,assign) uint32_t dataSize;
@property (nonatomic,assign) double duration;

+(AudioCompressData *)initWithBuffer:(char *)buffer size:(uint32_t)size time:(double)timeStamp;
@end
