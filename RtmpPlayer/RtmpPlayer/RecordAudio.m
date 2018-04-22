//
//  RecordAudio.m
//  RtmpPlayer
//
//  Created by clj on 16/9/1.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "RecordAudio.h"
#import "RecordManager.h"
#define t_sample             SInt16
#define kNumberBuffers 3
#define kSamplingRate 44100
#define kNumberChannels     1
#define kBitsPerChannels    (sizeof(t_sample) * 8)
#define kBytesPerFrame      (kNumberChannels * sizeof(t_sample))
//#define kFrameSize          (kSamplingRate * sizeof(t_sample))
#define kFrameSize          1024
typedef struct RecordAudioData{

    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef               queue;
    AudioQueueBufferRef         mBuffers[kNumberBuffers];
    AudioFileID                 outputFile;
    
    UInt32                      frameSize;
    long long                   recPtr;
    int                         run;
    
}RecordAudioData;

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

static void add_adts_header(unsigned char *p, int es_len) {
    int frame_len = 7 + es_len;
    static int m_channel = 1; // 双声道
    static int m_profile = 1; // AAC(Version 4) LC
    static int m_sampleRateIndex = 0x04;
    
    *p++ = 0xff;                                    //syncword  (0xfff, high_8bits)
    *p = 0xf0;                                      //syncword  (0xfff, low_4bits)
    *p |= (0 << 3);                                 //ID (0, 1bit)
    *p |= (0 << 1);                                 //layer (0, 2bits)
    *p |= 1;                                        //protection_absent (1, 1bit)
    p++;
    *p = (unsigned char) ((m_profile & 0x3) << 6);  //profile (profile, 2bits)
    *p |= ((m_sampleRateIndex & 0xf) << 2);         //sampling_frequency_index (sam_idx, 4bits)
    *p |= (0 << 1);                                 //private_bit (0, 1bit)
    *p |= ((m_channel & 0x4) >> 2);                 //channel_configuration (channel, high_1bit)
    p++;
    *p = ((m_channel & 0x3) << 6);                  //channel_configuration (channel, low_2bits)
    *p |= (0 << 5);                                 //original/copy (0, 1bit)
    *p |= (0 << 4);                                 //home  (0, 1bit);
    *p |= (0 << 3);                                 //copyright_identification_bit (0, 1bit)
    *p |= (0 << 2);                                 //copyright_identification_start (0, 1bit)
    *p |= ((frame_len & 0x1800) >> 11);             //frame_length (value, high_2bits)
    p++;
    *p++ = (unsigned char) ((frame_len & 0x7f8) >> 3);  //frame_length (value, middle_8bits)
    *p = (unsigned char) ((frame_len & 0x7) << 5);      //frame_length (value, low_3bits)
    *p |= 0x1f;                                         //adts_buffer_fullness (0x7ff, high_5bits)
    p++;
    *p = 0xfc;                                          //adts_buffer_fullness (0x7ff, low_6bits)
    *p |= 0;                                            //number_of_raw_data_blocks_in_frame (0, 2bits);
    p++;
}

@interface RecordAudio ()
{

    RecordAudioData aqc;
    
    AudioFileTypeID fileFormat;
    
    size_t timeStamp;
    size_t frameTime;
    dispatch_queue_t workQueue;//异步Queue
    RTMP *rtmp;
    double start_time;
    BOOL isSend;

}//rtmp://localhost:1935/rtmplive/room
@end


@implementation RecordAudio
static void AQInputCallback (void                   * inUserData,
                             AudioQueueRef          inAudioQueue,
                             AudioQueueBufferRef    inBuffer,
                             const AudioTimeStamp   * inStartTime,
                             unsigned long          inNumPackets,
                             const AudioStreamPacketDescription * inPacketDesc)
{
//    NSLog(@"22222：：：%d",inBuffer->mAudioDataByteSize);
    RecordAudio * engine = (__bridge RecordAudio *) inUserData;
    if (inNumPackets > 0)
    {
        [engine processAudioBuffer:inBuffer withQueue:inAudioQueue];
    }
    
    if (engine->aqc.run)
    {
        AudioQueueEnqueueBuffer(engine->aqc.queue, inBuffer, 0, NULL);
    }
}
- (instancetype)init{

    if (self = [super init]) {
        
        aqc.mDataFormat.mSampleRate = kSamplingRate;
        aqc.mDataFormat.mFormatID = kAudioFormatMPEG4AAC;
        aqc.mDataFormat.mFormatFlags = 0;
        aqc.mDataFormat.mFramesPerPacket = 1024;
        aqc.mDataFormat.mChannelsPerFrame = kNumberChannels;
        aqc.mDataFormat.mBitsPerChannel = 0;
        aqc.mDataFormat.mBytesPerPacket = 0;
        aqc.mDataFormat.mBytesPerFrame = 0;
        aqc.mDataFormat.mReserved = 0;
        aqc.frameSize = kFrameSize;
        frameTime = (1024.0*1000/kSamplingRate);//ms
        timeStamp = 0;
        [self setupAudioQueue];
        self->workQueue = dispatch_queue_create("rtmpSendQueue", NULL);


    }
    return self;

}
- (void)sendSpec{
    [self aacSequenceData];

}
- (void)setupAudioQueue{

   OSStatus status = AudioQueueNewInput(&aqc.mDataFormat, AQInputCallback,  (__bridge void *)self, NULL, kCFRunLoopCommonModes, 0, &aqc.queue);
    
    if (status != noErr) {
        NSLog(@"AudioQueueNewInput error");
        return;
    }
    for (int i=0;i<kNumberBuffers;i++)
    {
        status = AudioQueueAllocateBuffer(aqc.queue, aqc.frameSize, &aqc.mBuffers[i]);
        if (status != noErr) {
            NSLog(@"AudioQueueAllocateBuffer error");
            return;
        }
        status = AudioQueueEnqueueBuffer(aqc.queue, aqc.mBuffers[i], 0, NULL);
        if (status != noErr) {
            NSLog(@"AudioQueueEnqueueBuffer error");
            return;
        }
    }
    
    AudioQueueSetParameter(aqc.queue,  kAudioQueueParam_Volume, 1.0);
    aqc.recPtr = 0;
    aqc.run = 1;
    
}


- (void) processAudioBuffer:(AudioQueueBufferRef) buffer withQueue:(AudioQueueRef) queue
{

    uint8_t * data = (uint8_t *) buffer->mAudioData;
    //处理data
    NSMutableData *dataByte = [NSMutableData dataWithBytes:data length:buffer->mAudioDataByteSize];
    [self aacData:dataByte];

}
- (void)aacSequenceData{

//    //    flv头的前三个字节表示 flv 字符用0x46, 0x4C, 0x56表示
//    uint8_t flvH3Byte[3] = {0x46, 0x4C, 0x56};
//    [dataByte appendBytes:flvH3Byte length:sizeof(flvH3Byte)];
//    
//    //    Version: 第4个字节表示flv版本号.一般使用0x01表示
//    uint8_t flvH4Byte[1] = {0x01};
//    [dataByte appendBytes:flvH4Byte length:sizeof(flvH4Byte)];
//    
//    
//    //    Flags: 第5个字节中的第0位和第2位,分别表示 video 与 audio 存在的情况.(1表示存在,0表示不存在)流信息 1bytes：0x04，表示成二进制位0000 0100，在这8个bit中，倒数第一位为1则表示有视频，倒数第三位为1表示有音频，这里表示有音频 0x01 音频视频都有0x05
//    
//    uint8_t flvH5Byte[1] = {0x01};//只有视频
//    [dataByte appendBytes:flvH5Byte length:sizeof(flvH5Byte)];
//    
//    //最后4个字节表示FLV header 长度.
//    uint8_t flvH6_9Byte[4] = {0x00,0x00,0x00,0x09};//只有视频
//    [dataByte appendBytes:flvH6_9Byte length:sizeof(flvH6_9Byte)];
//    
//    //上个tag的大小应为这里没有tag所以全部为0
//    uint8_t tagSize[4] = {0x00,0x00,0x00,0x00};
//    [dataByte appendBytes:tagSize length:sizeof(tagSize)];
    
    
    /**
     第1个byte为记录着tag的类型，音频（0x8），视频（0x9），脚本（0x12）
     
     */
    NSMutableData *dataByte = [NSMutableData data];
    AudioTag audioTag = {0};
    
    audioTag.audioTagHeader.tagType = 0x08;
    uint32_t dataSize = 4;
    audioTag.audioTagHeader.dataSize[0] = ((dataSize&0x00FF0000) >> 16);
    audioTag.audioTagHeader.dataSize[1] = ((dataSize&0x0000FF00) >> 8);
    audioTag.audioTagHeader.dataSize[2] = (dataSize&0x000000FF);
    
    audioTag.audioTagHeader.timeStamp[0] = 0;
    audioTag.audioTagHeader.timeStamp[1] = 0;
    audioTag.audioTagHeader.timeStamp[2] = 0;
    
    audioTag.audioTagHeader.timeStampExtend = 0;
    audioTag.audioTagHeader.streamID[0] = 0;
    audioTag.audioTagHeader.streamID[1] = 0;
    audioTag.audioTagHeader.streamID[2] = 0;
    
    audioTag.audioTagData.sound_type4b_rate_size_channelNum = 0xAB;
    audioTag.audioTagData.aacPacketType = 0x00;
    audioTag.audioTagData.aacSpecificConfig[0] = 0xb;
    audioTag.audioTagData.aacSpecificConfig[1] = 0x88;
    
    [dataByte appendBytes:audioTag.audioTagData.aacSpecificConfig length:sizeof(audioTag.audioTagData.aacSpecificConfig)];
    
    [[RecordManager shareManager] send_rtmp_audio_spec:dataByte andLength:(uint32_t)dataByte.length];
   
}



- (void)aacData:(NSData *)data{

//    unsigned char *byte = ( unsigned char *)[data bytes];
    if (isSend == NO) {
        isSend = YES;
        [[RecordManager shareManager] firstFrameAudioData];
    }
    [[RecordManager shareManager] send_rtmp_audio:data andLength:(uint32_t)data.length];
    
}
- (void)dealloc
{
    AudioQueueStop(aqc.queue, true);
    aqc.run = 0;
    AudioQueueDispose(aqc.queue, true);
}


- (void)start
{
    OSStatus status = AudioQueueStart(aqc.queue, NULL);
    if (status != noErr) {
        NSLog(@"AudioQueueStart error");
        return;
    }
}

- (void)stop
{
    AudioQueueStop(aqc.queue, true);
}

- (void)pause
{
    AudioQueuePause(aqc.queue);
}
@end
