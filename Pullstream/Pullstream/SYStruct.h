//
//  SYStruct.h
//  Pullstream
//
//  Created by clj on 16/10/19.
//  Copyright © 2016年 clj. All rights reserved.
//

#ifndef SYStruct_h
#define SYStruct_h
#define Key_Frame 1
#define NO_Key_Frame 2
#define VIDEO_Type 1
#define AUDIO_Type 2
#import <CoreMedia/CoreMedia.h>
typedef struct AudioVideoSyTime{
    
    uint64_t audioStartTime;
    uint64_t audioEndTime;
    uint64_t startSequenceNo;
    uint64_t endSequenceNo;
    
    
}AudioVideoSyTime;
typedef struct VIDEO_SPS_PPS_TYPE{

    uint8_t *sps;
    uint8_t *pps;
    uint32_t spslen;
    uint32_t ppslen;
    
}VIDEO_SPS_PPS_TYPE;
typedef struct MediaFrameType{
    /* 音频*/
    int smaple_rate;
    int channel_num;
    int bit_rate;
    unsigned char *audio_frame_data;

    /*视频*/
    int frame_fps;
    int frame_type;/*关键帧还是非关键帧*/
    
    int media_type;
    size_t frame_size;
    CVPixelBufferRef video_frame_data;
    double frame_pts;
    double frame_duration;
}MediaFrameType;
typedef enum AudioVideoSyType{
    
    syType,
    VideoLagType,
    VideoAdvanceType
    
}AudioVideoSyType;
#define TMAX 25
#define VIDEO_DATA_MAX 25
#define AUDIO_DATA_MAX 15

#import "VideoCompressData.h"
#import "AudioCompressData.h"
#endif /* SYStruct_h */
