//
//  MediaFrame.m
//  Pullstream
//
//  Created by clj on 16/10/20.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "MediaFrame.h"

@implementation MediaFrame

+ (instancetype)createFrameWithInfo:(MediaFrameType )frame_info{

  
    return [[self alloc] initFrameWith:frame_info];
    
}
- (instancetype)initFrameWith:(MediaFrameType)frame_info{

    if (self = [super init]) {
        _frame_info = frame_info;
        if (_frame_info.media_type == VIDEO_Type) {
            _frame_info.frame_size = CVPixelBufferGetDataSize(_frame_info.video_frame_data);
        }
        
    }
    return self;
}
- (void)dealloc{

    if (_frame_info.video_frame_data) CVPixelBufferRelease(_frame_info.video_frame_data);
    _frame_info.video_frame_data = NULL;
    
    if (_frame_info.audio_frame_data) free(_frame_info.audio_frame_data);
    
    _frame_info.audio_frame_data = NULL;
    
}
@end
