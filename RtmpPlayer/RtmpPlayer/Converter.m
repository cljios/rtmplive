//
//  Converter.m
//  RtmpPlayer
//
//  Created by clj on 16/9/26.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "Converter.h"

@implementation Converter
static OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    Converter *encoder = (__bridge Converter *)(inUserData);
    UInt32 requestedPackets = *ioNumberDataPackets;
    //NSLog(@"Number of packets requested: %d", (unsigned int)requestedPackets);
    size_t copiedSamples = [encoder copyPCMSamplesIntoBuffer:ioData];
    if (copiedSamples < requestedPackets) {
        //NSLog(@"PCM buffer isn't full enough!");
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = 1;
    //NSLog(@"Copied %zu samples into ioData", copiedSamples);
    return noErr;
}
- (instancetype)init{

    if (self = [super init]) {
        
        _aacBufferSize = 1024;
        _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
    }
    return self;
}
-(BOOL)createAudioConvert:(AudioStreamBasicDescription)inputFormats pcmdata:(char *)data len:(uint32_t)len{ //根据输入样本初始化一个编码转换器
    if (m_converter != nil)
    {
        return YES;
    }
    
    AudioStreamBasicDescription inputFormat = inputFormats; // 输入音频格式
    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = inputFormat.mSampleRate; // 采样率保持一致
    outputFormat.mFormatID         = kAudioFormatMPEG4AAC;    // AAC编码
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mFramesPerPacket  = 1024;                    // AAC一帧是1024个字节
    
    AudioClassDescription *desc = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    if (AudioConverterNewSpecific(&inputFormat, &outputFormat, 1, desc, &m_converter) != noErr)
    {
        return NO;
    }
    
    return YES;
}
-(BOOL)encoderAAC:(AudioStreamBasicDescription)inputFormats  pcmData:(char*)pcmData pcmLen:(uint32_t)pcmLen { // 编码PCM成AAC
    if ([self createAudioConvert:inputFormats pcmdata:pcmData len:pcmLen] != YES)
    {
        return NO;
    }
//    pcm
    
    _pcmBuffer = malloc(pcmLen);
    _pcmBufferSize = pcmLen;
    memcpy(_pcmBuffer, pcmData, pcmLen);
    
    AudioBufferList inputBufferList;
    inputBufferList.mNumberBuffers              = 1;
    inputBufferList.mBuffers[0].mNumberChannels = 1;
    inputBufferList.mBuffers[0].mDataByteSize   = _pcmBufferSize; // 设置缓冲区大小
    inputBufferList.mBuffers[0].mData           = _pcmBuffer;
    // 初始化一个输出缓冲列表
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers              = 1;
    outBufferList.mBuffers[0].mNumberChannels = 2;
    outBufferList.mBuffers[0].mDataByteSize   = _aacBufferSize; // 设置缓冲区大小
    outBufferList.mBuffers[0].mData           = _aacBuffer; // 设置AAC缓冲区
    UInt32 outputDataPacketSize               = 1;
    OSStatus status = AudioConverterFillComplexBuffer(m_converter, inInputDataProc, (__bridge void *)self, &outputDataPacketSize, &outBufferList, NULL);
    if ( status!= noErr)
    {
        NSLog(@"AudioConverterFillComplexBuffer failed");
        return NO;
    }
    NSError *error = NULL;
    if (status == 0) {
//        NSData *rawAAC = [NSData dataWithBytes:outBufferList.mBuffers[0].mData length:outBufferList.mBuffers[0].mDataByteSize];
//        NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
//        NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
//        [fullData appendData:rawAAC];
    
        if (self.delegate && [self.delegate respondsToSelector:@selector(aacData:datalen:)]) {
            [self.delegate aacData:outBufferList.mBuffers[0].mData datalen:(uint32_t)outBufferList.mBuffers[0].mDataByteSize];
        }
    
    } else {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
    
    free(_pcmBuffer);
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
//    *aacLen = outBufferList.mBuffers[0].mDataByteSize; //设置编码后的AAC大小
    return YES;
}
- (NSData*) adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}
-(AudioClassDescription*)getAudioClassDescriptionWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer { // 获得相应的编码器
    static AudioClassDescription audioDesc;
    
    UInt32 encoderSpecifier = type, size = 0;
    OSStatus status;
    
    memset(&audioDesc, 0, sizeof(audioDesc));
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size);
    if (status)
    {
        return nil;
    }
    
    uint32_t count = size / sizeof(AudioClassDescription);
    AudioClassDescription descs[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, descs);
    for (uint32_t i = 0; i < count; i++)
    {
        if ((type == descs[i].mSubType) && (manufacturer == descs[i].mManufacturer))
        {
            memcpy(&audioDesc, &descs[i], sizeof(audioDesc));
            break;
        }
    }
    return &audioDesc;
}


- (size_t) copyPCMSamplesIntoBuffer:(AudioBufferList*)ioData {
    size_t originalBufferSize = _pcmBufferSize;
    if (!originalBufferSize) {
        return 0;
    }
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = _pcmBufferSize;
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
    return originalBufferSize;
}

@end
