//
//  VideoCompressData.h
//  Pullstream
//
//  Created by clj on 16/10/21.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoCompressData : NSObject
@property (nonatomic,assign) BOOL iskeyFrame;
@property (nonatomic,assign) double timeStamp;
@property (nonatomic,assign) char*buffer;
@property (nonatomic,assign) uint32_t dataSize;
@property (nonatomic,assign) double duration;
+(VideoCompressData *)initWithBuffer:(char *)buffer size:(uint32_t)size time:(double)timeStamp;
@end
