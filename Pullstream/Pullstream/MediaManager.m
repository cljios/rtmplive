//
//  MediaManager.m
//  Pullstream
//
//  Created by clj on 16/10/21.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "MediaManager.h"
#import <librtmp/rtmp.h>
#import <librtmp/log.h>
@interface MediaManager ()
{
    RTMP *rtmp;
    H264Decoder *videoCodecCtx;
    FAACDecoder *audioCodecCtx;
//    MediaFrame *videoFrame;
//    MediaFrame *audioFrame;
    NSMutableArray *videoFrames;
    NSMutableArray *audioFrames;
    NSString *h264;
    NSFileHandle *handle;
    
    
    pthread_mutex_t audio_mutex;
    pthread_cond_t audio_condition;
    pthread_mutex_t audioWait_mutex;
    pthread_cond_t audioWait_condition;

    pthread_mutex_t video_mutex;
    pthread_cond_t video_condition;
    CGFloat _currentTimeStamp;
    BOOL _isFirstFrame;
    BOOL deadCircleVideo;
    BOOL deadCircleAudio;

}
@end


@implementation MediaManager

- (void)setCurrentTimeStamp:(CGFloat)stamp{
    _currentTimeStamp = stamp;
}

- (instancetype)init{

    if (self = [super init]) {
        _currentTimeStamp = 0;
        _isFirstFrame = YES;
        videoCodecCtx = [H264Decoder new];
        audioCodecCtx = [[FAACDecoder alloc]
                         initCreateAACDecoderWithSample_rate:44100 channels:1 bit_rate:16];
        
        videoFrames = [NSMutableArray array];
        audioFrames = [NSMutableArray array];
        [self video_mutex_init];
        [self audio_mutex_init];
        [self audioWait_mutex_init];
        [self profileAudioSession];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        h264 = [documentsDirectory stringByAppendingPathComponent:@"me.h264"];
        [fileManager removeItemAtPath:h264 error:nil];
        [fileManager createFileAtPath:h264 contents:nil attributes:nil];
        
        // Open the file using POSIX as this is anyway a test application
        //fd = open([h264File UTF8String], O_RDWR);
        handle = [NSFileHandle fileHandleForWritingAtPath:h264];
    }
    return self;

}
#pragma mark 配置session

- (BOOL)profileAudioSession{
    
    
    
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    BOOL result = [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!result) {
        NSLog(@"AVAudioSession setCategory error :%@",error);
        return result;
    }
    Float32 preferredBufferSize = 0.0232;
//    AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
//                            sizeof(preferredBufferSize),
//                            &preferredBufferSize);

    [session setPreferredIOBufferDuration:preferredBufferSize error:&error];
    [session setPreferredSampleRate:44100 error:&error];
    result = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    if (!result) {
        NSLog(@"overrideOutputAudioPort error :%@",error);
        return result;
    }
    result = [session setActive:YES error:&error];
    if (!result) {
        NSLog(@"AVAudioSession setCategory error :%@",error);
        return result;
    }
    
    return YES;
    
}
- (BOOL)connectRtmpSever:(char *)url{
    
    //is live stream ?
    bool bLiveStream=true;
    
    //    FILE *fp=fopen("receive.flv","wb");
    //    if (!fp){
    //        RTMP_LogPrintf("Open File Error.\n");
    //        return NO;
    //    }
    
    /* set log level */
    RTMP_LogLevel loglvl=RTMP_LOGDEBUG;
    RTMP_LogSetLevel(loglvl);
    
    rtmp=RTMP_Alloc();
    RTMP_Init(rtmp);
    //set connection timeout,default 30s
    rtmp->Link.timeout=10;
    // HKS's live URL
    int err = RTMP_SetupURL(rtmp,url);
    if(!err)
    {
        RTMP_Log(RTMP_LOGERROR,"SetupURL Err\n");
        RTMP_Free(rtmp);
        return NO;
    }
    if (bLiveStream){
        rtmp->Link.lFlags|=RTMP_LF_LIVE;
    }
    
    //1hour
    RTMP_SetBufferMS(rtmp, 3600*1000);
    err = RTMP_Connect(rtmp,NULL);
    if(!err){
        RTMP_Log(RTMP_LOGERROR,"Connect Err\n");
        RTMP_Free(rtmp);
        return NO;
    }
    err = RTMP_ConnectStream(rtmp,0);
    if(!err){
        RTMP_Log(RTMP_LOGERROR,"ConnectStream Err\n");
        RTMP_Close(rtmp);
        RTMP_Free(rtmp);
        return NO;
    }
    
    
    
    return YES;
    
    
}
- (void)rtmpDisconnect{
    
    RTMP_Log(RTMP_LOGERROR,"ConnectStream Err\n");
    RTMP_Close(rtmp);
    RTMP_Free(rtmp);
    rtmp=NULL;
    
}
- (void)decodeFrame{

    int error = 1;
    while(error) {
        
        RTMPPacket packet;
        
        error =  RTMP_ReadPacket(rtmp, &packet);
        
        if (!RTMPPacket_IsReady(&packet)) {
            RTMPPacket_Free(&packet);
            continue;
        }
        if (packet.m_body == NULL){
            RTMPPacket_Free(&packet);
            continue;
        }
        
        if (!RTMP_ClientPacket(rtmp, &packet)) {
            RTMPPacket_Free(&packet);
            continue;
        }
        
        if (packet.m_packetType == RTMP_PACKET_TYPE_VIDEO) {
            
            if (packet.m_body[0] == 0x17) {
                
                if (packet.m_body[1] == 0x00) {
                   
                    @autoreleasepool {
                        //                    sps pps
                        uint32_t spslen =  (packet.m_body[11]&0x000000FF) << 8 | (packet.m_body[12]&0x000000FF);
                        
                        uint32_t ppslen = (packet.m_body[14+spslen]&0x000000FF) << 8| (packet.m_body[15+spslen]&0x000000FF);
                        //                    NSData *daddd = [NSData dataWithBytes:packet.m_body length:packet.m_nBodySize];
                        
                        BOOL result = [videoCodecCtx initH264DecoderWithSPS:&packet.m_body[13] spslen:spslen pps:&packet.m_body[16+spslen] ppslen:ppslen];
                        //                    char startCode[4] = {0,0,0,1};
                        //                    NSData *dc = [NSData dataWithBytes:startCode length:4];
                        //
                        //                    [handle writeData:dc];
                        //                    NSData *sp = [NSData dataWithBytes:&packet.m_body[13] length:spslen];
                        //                    [handle writeData:sp];
                        //
                        //                    [handle writeData:dc];
                        //                    NSData *pp = [NSData dataWithBytes:&packet.m_body[16+spslen] length:ppslen];
                        //                    [handle writeData:pp];
                        
                        
                        if (result == NO) {
                            NSLog(@"视频解码器初始化失败");
                        }
                    }
                    
                }else if (packet.m_body[1] == 0x01){
                    
                    
//                    char startCode[4] = {0,0,0,1};
//                    NSData *dc = [NSData dataWithBytes:startCode length:4];
//                    [handle writeData:dc];
//                    NSData *daby = [NSData dataWithBytes:&packet.m_body[9] length:datalen];
//                    [handle writeData:daby];

                    @autoreleasepool {
                        int datalen = 0;
                        int num = 5;
                        char *data = packet.m_body;
                        
                        datalen = (data[num]&0x000000FF)<<24|(data[num+1]&0x000000FF)<<16|(data[num+2]&0x000000FF)<<8|(data[num+3]&0x000000FF);
                        VideoCompressData *videoCompressData = [VideoCompressData initWithBuffer:&packet.m_body[9] size:datalen time:packet.m_nTimeStamp];
                        
                        MediaFrame *videoFrame = nil;
                        [videoCodecCtx decodeVideoFrameData:videoCompressData YUVData:&videoFrame];
                        videoCompressData = nil;
                        if (videoFrame) [self addFrame:videoFrame];
                        
                    }
                    
                }
                
            }else if (packet.m_body[0] == 0x27){
               
                @autoreleasepool {
                    int datalen = 0;
                    int num = 5;
                    char *data = packet.m_body;
                    
                    datalen = (data[num]&0x000000FF)<<24|(data[num+1]&0x000000FF)<<16|(data[num+2]&0x000000FF)<<8|(data[num+3]&0x000000FF);
                    
                    //                char startCode[4] = {0,0,0,1};
                    //                NSData *dc = [NSData dataWithBytes:startCode length:4];
                    //                [handle writeData:dc];
                    //                NSData *daby = [NSData dataWithBytes:&packet.m_body[9] length:datalen];
                    //                [handle writeData:daby];
                    
                    VideoCompressData *videoCompressData = [VideoCompressData initWithBuffer:&packet.m_body[9] size:datalen time:packet.m_nTimeStamp];
                    
                    MediaFrame *videoFrame = nil;
                    [videoCodecCtx decodeVideoFrameData:videoCompressData YUVData:&videoFrame];
                    videoCompressData = nil;
                    
                    
                    if (videoFrame) [self addFrame:videoFrame];
                }
                
                
                
            }
            
            
            
        }else if (packet.m_packetType == RTMP_PACKET_TYPE_AUDIO){

//            NSMutableData *data = [NSMutableData dataWithBytes:packet.m_body length:packet.m_nBytesRead];
            
            
            if (packet.m_body[1] == 0x01) {
                
                @autoreleasepool {
//                    char *audiodata = malloc(packet.m_nBodySize - 2);
//                    memcpy(audiodata, &packet.m_body[2], packet.m_nBodySize - 2);
                    
                    AudioCompressData *audioCompressData = [AudioCompressData initWithBuffer:&packet.m_body[2] size:packet.m_nBodySize-2 time:packet.m_nTimeStamp];
                    
                    MediaFrame *audioFrame = nil;

                    [audioCodecCtx decodeAudioAACFrameData:audioCompressData pcmData:&audioFrame];
                    if (audioFrame)[self addFrame:audioFrame];
//                    NSData *data = [NSData dataWithBytes:audioFrame->_frame_info.audio_frame_data  length:audioFrame->_frame_info.frame_size];
//                    if (data.length> 0) {
//                        [handle writeData:data];
//                    }

                }
                

                
                
                
                
                
            }else{
                
                
            }
        }
        RTMPPacket_Free(&packet);
    }
    
}

- (void)addFrame:(MediaFrame *)frame{

    if (_isFirstFrame && frame->_frame_info.media_type == AUDIO_Type) {
        _currentTimeStamp = frame->_frame_info.frame_pts;
        _isFirstFrame = NO;
    }
    if (frame->_frame_info.media_type == VIDEO_Type) {
        
        pthread_mutex_lock(&video_mutex);
        while (videoFrames.count >= VIDEO_DATA_MAX) {
            pthread_cond_wait(&video_condition, &video_mutex);
        }
        [videoFrames addObject:frame];
        [self audioWait_cond_signal];
        pthread_mutex_unlock(&video_mutex);
        
    }else if (frame->_frame_info.media_type == AUDIO_Type){
    
        pthread_mutex_lock(&audio_mutex);
        while (audioFrames.count >= AUDIO_DATA_MAX) {
            pthread_cond_wait(&audio_condition, &audio_mutex);
        }
        [audioFrames addObject:frame];
        pthread_mutex_unlock(&audio_mutex);
    }
}

- (MediaFrame *)presentFrame{

    MediaFrame *frame = nil;
    pthread_mutex_lock(&video_mutex);

    if (videoFrames.count > 0) {
        frame = [videoFrames firstObject];
        const CGFloat delta = _currentTimeStamp - frame->_frame_info.frame_pts;
        
        if (delta < -0.03) {
            deadCircleVideo = YES;
            frame = nil;
        }else if (delta > 0.03){
            deadCircleAudio = NO;
            [videoFrames removeObjectAtIndex:0];
        }else{
            deadCircleAudio = NO;
            [videoFrames removeObjectAtIndex:0];
            _currentTimeStamp = frame->_frame_info.frame_pts;
        }
    }else{
        deadCircleAudio = NO;
        _currentTimeStamp = -1;
    }
    
    pthread_cond_signal(&video_condition);
    pthread_mutex_unlock(&video_mutex);
    
    return frame;

}
- (__autoreleasing NSArray *)presentVideoFrame{

    NSMutableArray *videoArray = nil;
    pthread_mutex_lock(&video_mutex);
    @autoreleasepool {
        NSUInteger arrCount = videoFrames.count;
        if (arrCount > 0) {
            videoArray = [NSMutableArray array];
            while (true) {
                MediaFrame *frame = [videoFrames firstObject];
                if (frame) {
                    float video_timeStamp = frame->_frame_info.frame_pts;
                    float delta = _currentTimeStamp - video_timeStamp;
                    if (delta < - 0.01) {
                        //                frame->_frame_info.frame_duration = delta+audioPlayTime;
                        //                [videoArray addObject:frame];
                        
                        break;
                    }else if (delta > 0.01){
                        //跳帧
                        if (videoFrames.count > 0) {
                            [videoFrames removeObjectAtIndex:0];
                        }
                        continue;
                    }else{
                        if (frame) {
                            [videoArray addObject:frame];
                            [videoFrames removeObjectAtIndex:0];
                        }
                        
                    }
                }else{
                    break;
                }
                
            }
        }
    }
    if (videoFrames.count < 15) {
        pthread_cond_signal(&video_condition);
    }
    pthread_mutex_unlock(&video_mutex);

    
    return videoArray;

}

- (MediaFrame *)playAudioFrame{
    
    MediaFrame *frame = nil;
    pthread_mutex_lock(&audio_mutex);
    if (audioFrames.count > 0) {
        frame = [audioFrames firstObject];
        _currentTimeStamp = frame->_frame_info.frame_pts;
        [audioFrames removeObjectAtIndex:0];
    }else{
        [self audioWait_mutex_wait];
    }
    if (audioFrames.count < 10) {
        pthread_cond_signal(&audio_condition);
    }
    pthread_mutex_unlock(&audio_mutex);
    return frame;


}

- (MediaFrame *)getAudioFrame{

    MediaFrame *frame = nil;
    
    pthread_mutex_lock(&audio_mutex);

    
    if (audioFrames.count > 0) {

        frame = [audioFrames firstObject];
        if (_currentTimeStamp == -1) {
            _currentTimeStamp = frame->_frame_info.frame_pts;
        }
        const CGFloat delta = _currentTimeStamp - frame->_frame_info.frame_pts;
        
        if (delta < -0.03) {
            deadCircleAudio = YES;
            if (deadCircleVideo && deadCircleAudio) {
                _currentTimeStamp = frame->_frame_info.frame_pts;
            }
            frame = nil;
            
        }else if (delta > 0.03){
            deadCircleAudio = NO;
            [audioFrames removeObjectAtIndex:0];
        }else{
            deadCircleAudio = NO;
            [audioFrames removeObjectAtIndex:0];
            _currentTimeStamp = frame->_frame_info.frame_pts;
        }
    }
    pthread_cond_signal(&audio_condition);
    pthread_mutex_unlock(&audio_mutex);
    
    return frame;

}

- (void)video_mutex_init{
    pthread_mutex_init(&video_mutex,NULL);
    pthread_cond_init(&video_condition, NULL);

}
- (void)video_mutex_wait{
    pthread_mutex_lock(&video_mutex);
    pthread_cond_wait(&video_condition, &video_mutex);
    pthread_mutex_unlock(&video_mutex);
    
}
- (void)video_cond_signal{
    pthread_mutex_lock(&video_mutex);
    pthread_cond_signal(&video_condition);
    pthread_mutex_unlock(&video_mutex);
}
- (void)audio_mutex_init{
    pthread_mutex_init(&audio_mutex,NULL);
    pthread_cond_init(&audio_condition, NULL);

}

- (void)audio_mutex_wait{
    pthread_mutex_lock(&audio_mutex);
    pthread_cond_wait(&audio_condition, &audio_mutex);
    pthread_mutex_unlock(&audio_mutex);
}

- (void)audio_cond_signal{
    pthread_mutex_lock(&audio_mutex);
    pthread_cond_signal(&audio_condition);
    pthread_mutex_unlock(&audio_mutex);
}


- (void)audioWait_mutex_init{
    pthread_mutex_init(&audioWait_mutex,NULL);
    pthread_cond_init(&audioWait_condition, NULL);
}

- (void)audioWait_mutex_wait{
    pthread_mutex_lock(&audioWait_mutex);
    pthread_cond_wait(&audioWait_condition, &audioWait_mutex);
    pthread_mutex_unlock(&audioWait_mutex);
}
- (void)audioWait_cond_signal{
    pthread_mutex_lock(&audioWait_mutex);
    pthread_cond_signal(&audioWait_condition);
    pthread_mutex_unlock(&audioWait_mutex);
    
}
@end
