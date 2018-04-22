//
//  RecordManager.m
//  RtmpPlayer
//
//  Created by clj on 16/9/1.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "RecordManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <librtmp/rtmp.h>
#import <librtmp/log.h>
#include <sys/time.h>
enum nal_unit_type_e
{
    NAL_UNKNOWN     = 0,
    NAL_SLICE       = 1,
    NAL_SLICE_DPA   = 2,
    NAL_SLICE_DPB   = 3,
    NAL_SLICE_DPC   = 4,
    NAL_SLICE_IDR   = 5,    /* ref_idc != 0 */
    NAL_SEI         = 6,    /* ref_idc == 0 */
    NAL_SPS         = 7,
    NAL_PPS         = 8,
    NAL_AUD         = 9,
    NAL_FILLER      = 12,
    /* ref_idc == 0 for 6,9,10,11,12 */
};
static RecordManager *manager = nil;

typedef struct AudioTagHeader{
    
    uint8_t tagType;
    uint8_t dataSize[3];
    uint8_t timeStamp[3];
    uint8_t timeStampExtend;
    uint8_t streamID[3];
    
}AudioTagHeader;

typedef struct AudioTagData{
    
    uint8_t sound_type4b_rate_size_channelNum;
    uint8_t aacPacketType;
    uint8_t aacSpecificConfig[2];
    
    
}AudioTagData;
typedef struct AudioTag{
    
    AudioTagHeader audioTagHeader;
    AudioTagData audioTagData;
    uint8_t preTagSize[4];
    
}AudioTag;
@interface RecordManager ()
{
    RTMP* rtmp;
    dispatch_queue_t workQueue;//异步Queue
    struct timeval start,end;
    uint64_t num;
    BOOL audioIsSend;
}
@property (copy, nonatomic) NSString *h264File;
@property (retain, nonatomic) NSFileHandle *fileHandle;
@property (nonatomic,copy) NSString* rtmpUrl;//rtmp服务器流地址
@property (nonatomic,assign)double start_time;

@end

@implementation RecordManager

- (instancetype)init{
    
    if ((self = [super init])) {
        
        [self setupProfile];
        self->workQueue = dispatch_queue_create("rtmpSendQueue", NULL);
        _start_time = 0;
        num = 0;
    }
    return self;
}

- (double)start_time{

    if (_start_time == 0) {
        _start_time = [[NSDate date] timeIntervalSince1970]*1000;
    }

    return _start_time;
}
- (long long)getMsTime{
    gettimeofday(&end, NULL);
    long long timeUse = 1000000*(end.tv_sec - start.tv_sec)+end.tv_usec-start.tv_usec;
    return timeUse;
}

+ (id)shareManager{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!manager) {
            manager = [RecordManager new];
        }
    });
    return manager;
}

- (BOOL)setupProfile{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.h264File = [documentsDirectory stringByAppendingPathComponent:@"me.h264"];
    [fileManager removeItemAtPath:self.h264File error:nil];
    [fileManager createFileAtPath:self.h264File contents:nil attributes:nil];
    
    // Open the file using POSIX as this is anyway a test application
    //fd = open([h264File UTF8String], O_RDWR);
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.h264File];
    
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    BOOL result = [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (!result) {
        NSLog(@"AVAudioSession setCategory error :%@",error);
        return result;
    }
    result = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    
    result = [session setActive:YES error:&error];
    if (!result) {
        NSLog(@"AVAudioSession setCategory error :%@",error);
        return result;
    }
    
    return result;
}

- (void)writeRecordData:(NSData *)data {
    
    if (data == nil) {
        return;
    }
    [self.fileHandle writeData:data];
}
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

- (void)send_rtmp_audio_spec:(NSData *)spec_buf andLength:(uint32_t) spec_len
{
    
    //    __block uint32_t len = spec_len; /*spec data长度,一般是2*/
    dispatch_async(self->workQueue, ^{
        if(self->rtmp != NULL)
        {
            
            char* buffer = (char *)spec_buf.bytes;
            RTMPPacket * packet;
            unsigned char * body;
            
            packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE+4);
            memset(packet,0,RTMP_HEAD_SIZE);
            
            packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
            body = (unsigned char *)packet->m_body;
            
            /*AF 00 + AAC RAW data*/
            body[0] = 0xAF;
            body[1] = 0x00;
            memcpy(&body[2],buffer,2); /*spec_buf是AAC sequence header数据*/
            
            packet->m_packetType = RTMP_PACKET_TYPE_AUDIO;
            packet->m_nBodySize = 4;
            packet->m_nChannel = 0x05;
            packet->m_nTimeStamp = 0;
            packet->m_hasAbsTimestamp = 0;
            packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
            packet->m_nInfoField2 = rtmp->m_stream_id;
            
            if(RTMP_IsConnected(self->rtmp))
            {
                /*调用发送接口*/
                int success = RTMP_SendPacket(self->rtmp,packet,TRUE);
                if(success != 1)
                {
//                    NSLog(@"send_rtmp_audio_spec fail");
                }else{
                    //                    NSLog(@"send_rtmp_audio_spec success");
                    
                }
            }
            free(packet);
        }
        else
        {
            NSLog(@"send_rtmp_audio_spec RTMP is not ready");
        }
    });
}

- (void)send_rtmp_audio:(NSData *)buf andLength:(uint32_t)len
{
    audioIsSend = YES;
    dispatch_async(self->workQueue, ^{
        
        uint32_t length = len;
        
        char* buffer = (char *)buf.bytes;

        if(self->rtmp != NULL)
        {
            uint32_t timeoffset = [[NSDate date] timeIntervalSince1970]*1000 - self.start_time;
            num++;
            NSLog(@"音频时间戳:%u，包号：%llu",timeoffset,num);
            
            //            buffer += 7;
            //            length -= 7;
            
            if (length > 0)
            {
                RTMPPacket * packet;
                unsigned char * body;
                
                packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE + length + 2);
                memset(packet,0,RTMP_HEAD_SIZE);
                
                packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
                body = (unsigned char *)packet->m_body;
                
                /*AF 01 + AAC RAW data*/
                body[0] = 0xAF;
                body[1] = 0x01;
                memcpy(&body[2],buffer,length);
                
                packet->m_packetType = RTMP_PACKET_TYPE_AUDIO;
                packet->m_nBodySize = length + 2;
                packet->m_nChannel = 0x05;
                packet->m_nTimeStamp = timeoffset;
                packet->m_hasAbsTimestamp = 0;
                packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
                packet->m_nInfoField2 = rtmp->m_stream_id;
                
                if(RTMP_IsConnected(self->rtmp))
                {
                    /*调用发送接口*/
                    int success = RTMP_SendPacket(self->rtmp,packet,TRUE);
                    if(success != 1)
                    {
//                        NSLog(@"send_rtmp_audio fail");
                    }else{
                        
//                        NSLog(@"send_rtmp_audio success%d",len);
                        
                    }
                }
                free(packet);
            }
        }
        else
        {
//            NSLog(@"send_rtmp_audio RTMP is not ready");
        }
    });
    
    
}
- (BOOL)startRtmpConnect:(NSString *)urlString
{
    self.rtmpUrl = urlString;
    if(self->rtmp)
    {
        [self stopRtmpConnect];
    }
    
    self->rtmp = RTMP_Alloc();
    RTMP_Init(self->rtmp);
    int err = RTMP_SetupURL(self->rtmp, (char*)[_rtmpUrl cStringUsingEncoding:NSASCIIStringEncoding]);
    
    if(err < 0)
    {
        NSLog(@"RTMP_SetupURL failed");
        RTMP_Free(self->rtmp);
        return NO;
    }
    
    RTMP_EnableWrite(self->rtmp);
    
    err = RTMP_Connect(self->rtmp, NULL);
    
    if(err < 0)
    {
        NSLog(@"RTMP_Connect failed");
        RTMP_Free(self->rtmp);
        return NO;
    }
    
    err = RTMP_ConnectStream(self->rtmp, 0);
    
    if(err < 0)
    {
        NSLog(@"RTMP_ConnectStream failed");
        RTMP_Close(self->rtmp);
        RTMP_Free(self->rtmp);
        exit(0);
        return NO;
    }
    
    self.start_time = 0;
    
    return YES;
}
- (BOOL)stopRtmpConnect
{
    if(self->rtmp != NULL)
    {
        RTMP_Close(self->rtmp);
        RTMP_Free(self->rtmp);
        return true;
    }
    return false;
}
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

- (void)send_video_sps_pps:(NSData *)sps andSpsLength:(uint32_t)sps_len andPPs:(NSData *)pps andPPsLength:(uint32_t)pps_len
{
    dispatch_async(self->workQueue, ^{
        if(self->rtmp!= NULL)
        {

            
            char *SPS = (char *)sps.bytes;
            char *PPS = (char *)pps.bytes;

            RTMPPacket * packet;
            unsigned char * body;
            int i = 0;
            
            packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE+16);
            memset(packet,0,RTMP_HEAD_SIZE);
            
            packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
            body = (unsigned char *)packet->m_body;
            body[i++] = 0x17;
            body[i++] = 0x00;
            
            body[i++] = 0x00;
            body[i++] = 0x00;
            body[i++] = 0x00;
            
            /*AVCDecoderConfigurationRecord*/
            body[i++] = 0x01;
            body[i++] = SPS[1];
            body[i++] = SPS[2];
            body[i++] = SPS[3];
            body[i++] = 0xff;
            
            /*sps*/
            body[i++]   = 0xe1;
            body[i++] = (sps_len >> 8) & 0xff;
            body[i++] = sps_len & 0xff;
            memcpy(&body[i],SPS,sps_len);
            i +=  sps_len;
            
            /*pps*/
            body[i++]   = 0x01;
            body[i++] = (pps_len >> 8) & 0xff;
            body[i++] = (pps_len) & 0xff;
            memcpy(&body[i],PPS,pps_len);
            i +=  pps_len;
            
            packet->m_packetType = RTMP_PACKET_TYPE_VIDEO;
            packet->m_nBodySize = i;
            packet->m_nChannel = 0x04;
            packet->m_nTimeStamp = 0;
            packet->m_hasAbsTimestamp = 0;
            packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
            packet->m_nInfoField2 = self->rtmp->m_stream_id;
            
            if(RTMP_IsConnected(self->rtmp))
            {
                //调用发送接口
                int success = RTMP_SendPacket(self->rtmp,packet,TRUE);
                if(success != 1)
                {
//                    NSLog(@"send_video_sps_pps fail");
                    
                }else{
//                    NSLog(@"send_rtmp_video success");
                    
                }
                
            }
            free(packet);
        }
        else
        {
            NSLog(@"send_video_sps_pps RTMP is not ready");
        }
    });
    
}

- (void)send_rtmp_video:(NSData*)buf andLength:(uint32_t)length
{
    dispatch_async(self->workQueue, ^{

        char *buffer = (char *)buf.bytes;
        if(self->rtmp != NULL)
        {
            int type;
            RTMPPacket * packet;
            unsigned char * body;
            
            uint32_t timeoffset = [[NSDate date] timeIntervalSince1970]*1000 - self.start_time;  /*start_time为开始直播时的时间戳*/
            num++;
            NSLog(@"视频时间戳:%u，包号：%llu",timeoffset,num);

            /*去掉帧界定符(这里可能2种,但是sps or  pps只能为 00 00 00 01)*/
//            if (buffer[2] == 0x00){ /*00 00 00 01*/
//                buffer += 4;
//                length -= 4;
//            } else if (buffer[2] == 0x01){ /*00 00 01*/
//                buffer += 3;
//                length -= 3;
//            }
            
            type = buffer[0]&0x1f;
            
            packet = (RTMPPacket *)malloc(RTMP_HEAD_SIZE + length + 9);
            memset(packet,0,RTMP_HEAD_SIZE);
            
            packet->m_body = (char *)packet + RTMP_HEAD_SIZE;
            packet->m_nBodySize = length + 9;
            
            /*send video packet*/
            body = (unsigned char *)packet->m_body;
            memset(body,0,length + 9);
            
            /*key frame*/
            body[0] = 0x27;
            if (type == NAL_SLICE_IDR)//此为关键帧
            {
                body[0] = 0x17;
            }
            
            body[1] = 0x01;   /*nal unit*/
            body[2] = 0x00;
            body[3] = 0x00;
            body[4] = 0x00;
            
            body[5] = (length >> 24) & 0xff;
            body[6] = (length >> 16) & 0xff;
            body[7] = (length >>  8) & 0xff;
            body[8] = (length ) & 0xff;
            
            /*copy data*/
            memcpy(&body[9],buffer,length);
            
            packet->m_hasAbsTimestamp = 0;
            packet->m_packetType = RTMP_PACKET_TYPE_VIDEO;
            packet->m_nInfoField2 = self->rtmp->m_stream_id;
            packet->m_nChannel = 0x04;
            packet->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
            packet->m_nTimeStamp = timeoffset;
            
            if(RTMP_IsConnected(self->rtmp))
            {
                // 调用发送接口
                
                int success = RTMP_SendPacket(self->rtmp,packet,TRUE);
                if(success != 1)
                {
//                    NSLog(@"send_rtmp_video fail");
                }else{
//                    NSLog(@"send_rtmp_video success");
                    
                }
            }
            free(packet);
        }
        else
        {
//            NSLog(@"send_rtmp_video RTMP is not ready");
        }
    });
}

- (void)firstFrameAudioData{
    
    NSMutableData *dataByte = [NSMutableData data];
    AudioTag audioTag = {0};
    audioTag.audioTagData.aacSpecificConfig[0] = 0xb;
    audioTag.audioTagData.aacSpecificConfig[1] = 0x88;
    [dataByte appendBytes:audioTag.audioTagData.aacSpecificConfig length:sizeof(audioTag.audioTagData.aacSpecificConfig)];
    [self send_rtmp_audio_spec:dataByte andLength:(uint32_t)dataByte.length];
    
}


@end
