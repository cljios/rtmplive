//
//  AudioCompressData.m
//  Pullstream
//
//  Created by clj on 16/10/22.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "AudioCompressData.h"

@implementation AudioCompressData
+(AudioCompressData *)initWithBuffer:(char *)buffer size:(uint32_t)size time:(double)timeStamp{
    
    return [[self alloc] initWithBuffer:buffer size:size time:timeStamp];
    
}


- (instancetype)initWithBuffer:(char *)buffer size:(uint32_t)size time:(double)timeStamp{
    
    if (self = [super init]) {
        
        _dataSize = size+7;
        _timeStamp = timeStamp;
        _duration = 0.04;
        _buffer = malloc(_dataSize);
        memcpy(_buffer+7, buffer, size);
        
    }
    return self;
}
-(void)dealloc{
    
    if (_buffer) free(_buffer);
    _buffer = NULL;
    _dataSize = _timeStamp= 0;
    
}
@end
