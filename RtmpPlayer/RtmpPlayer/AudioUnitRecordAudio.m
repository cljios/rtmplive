//
//  AudioUnitRecordAudio.m
//  RtmpPlayer
//
//  Created by clj on 16/9/24.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "AudioUnitRecordAudio.h"
#import <AudioToolbox/AudioToolbox.h>
#import "RecordManager.h"
// 检测状态
void checkStatus(OSStatus status) {
    if(status!=0)
        printf("Error: %d\n", (int)status);
}
@interface AudioUnitRecordAudio()
{
    AudioBuffer _tempBuffer;
    AudioUnit audioUnit;
    AudioStreamBasicDescription audioFormat;

}

@end

@implementation AudioUnitRecordAudio
#define kOutputBus 0
#define kInputBus 1
// Bus 0 is used for the output side, bus 1 is used to get audio input.
#pragma mark Recording Callback
static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    
    
    AudioUnitRecordAudio *iosAudio = (__bridge AudioUnitRecordAudio *)inRefCon;
    AudioBuffer buffer;
    OSStatus status;
    buffer.mDataByteSize = inNumberFrames *2;
    buffer.mNumberChannels = 1;
    buffer.mData= malloc(inNumberFrames *2);
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0] = buffer;
    status = AudioUnitRender(iosAudio->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
//    [iosAudio processAudio:&bufferList];
//    NSLog(@"%u", (unsigned int)bufferList.mBuffers[0].mDataByteSize);
    //    NSLog(@"%@", bufferList.mBuffers[0].mData);
//    NSData *data = [NSData dataWithBytes:bufferList.mBuffers[0].mData length:bufferList.mBuffers[0].mDataByteSize];
//    NSLog(@"data:%@",data);
//    fwrite(bufferList.mBuffers[0].mData, bufferList.mBuffers[0].mDataByteSize,1 , pFile);
//    fflush(pFile);
    if (iosAudio->_delegate && [iosAudio->_delegate respondsToSelector:@selector(pcmData:datalen:inputFormat:)]) {
        [iosAudio->_delegate pcmData:bufferList.mBuffers[0].mData datalen:bufferList.mBuffers[0].mDataByteSize inputFormat:iosAudio->audioFormat];
    }
    free(bufferList.mBuffers[0].mData);
    
    return noErr;
}

/**
 This callback is called when the audioUnit needs new data to play through the
 speakers. If you don't have any, just don't write anything in the buffers
 */
- (void) processAudioBuffer:(AudioBufferList*) buffer{
    if (buffer == NULL) {
        return;
    }

    AudioBuffer ioBuffer = buffer->mBuffers[0];
    if (_tempBuffer.mDataByteSize < ioBuffer.mDataByteSize) {
        free(_tempBuffer.mData);
        _tempBuffer.mDataByteSize = ioBuffer.mDataByteSize;
        _tempBuffer.mData = malloc(ioBuffer.mDataByteSize);
    }
    memset(_tempBuffer.mData, 0, _tempBuffer.mDataByteSize);
    memcpy(_tempBuffer.mData, ioBuffer.mData, ioBuffer.mDataByteSize);
    [self aacData:[NSData dataWithBytes:_tempBuffer.mData length:ioBuffer.mDataByteSize]];
}
-(id)init{
    if (self = [super init]) {
        
        OSStatus status;
        
        // Describe audio component
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
        
        // Get audio units
        status = AudioComponentInstanceNew(inputComponent, &audioUnit);
        checkStatus(status);
        
        // Enable IO for recording
        UInt32 flag = 1;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      1,
                                      &flag,
                                      sizeof(flag));
        checkStatus(status);
        UInt32 echoCancellation;
        UInt32 size = sizeof(echoCancellation);

        status = AudioUnitGetProperty(audioUnit,
                             kAUVoiceIOProperty_BypassVoiceProcessing,
                             kAudioUnitScope_Global,
                             0,
                             &echoCancellation,
                             &size);
        
        checkStatus(status);

        // Describe format
//        audioFormat.mSampleRate                 = 44100.00;
//        audioFormat.mFormatID                   = kAudioFormatMPEG4AAC;
//        audioFormat.mFormatFlags                = 0;
//        audioFormat.mFramesPerPacket    = 1024;
//        audioFormat.mChannelsPerFrame   = 1;
//        audioFormat.mBitsPerChannel             = 0;
//        audioFormat.mBytesPerPacket             = 0;
//        audioFormat.mBytesPerFrame              = 0;
//        audioFormat.mReserved = 0;
//        audioFormat.mSampleRate			= 8000.00;
//        audioFormat.mFormatID			= kAudioFormatLinearPCM;
//        audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
//        audioFormat.mFramesPerPacket	= 1;
//        audioFormat.mChannelsPerFrame	= 1;
//        audioFormat.mBitsPerChannel		= 16;
//        audioFormat.mBytesPerPacket		= 2;
//        audioFormat.mBytesPerFrame		= 2;
        audioFormat.mSampleRate         = 44100;
        audioFormat.mFormatID           = kAudioFormatLinearPCM;
        audioFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioFormat.mFramesPerPacket    = 1;
        audioFormat.mChannelsPerFrame   = 1;
        audioFormat.mBitsPerChannel     = 16;
        audioFormat.mBytesPerPacket     =
        audioFormat.mBytesPerFrame      = audioFormat.mChannelsPerFrame * sizeof(SInt16);
        // Apply format
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &audioFormat,
                                      sizeof(audioFormat));
        checkStatus(status);
        //    status = AudioUnitSetProperty(audioUnit,
        //                                  kAudioUnitProperty_StreamFormat,
        //                                  kAudioUnitScope_Input,
        //                                  kOutputBus,
        //                                  &audioFormat,
        //                                  sizeof(audioFormat));
        //    checkStatus(status);
        
        
        // Set input callback
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = recordingCallback;
        callbackStruct.inputProcRefCon =(__bridge void *) self;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      kInputBus,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        checkStatus(status);
        
        // Set output callback
        //    callbackStruct.inputProc = playbackCallback;
        //    callbackStruct.inputProcRefCon = self;
        //    status = AudioUnitSetProperty(audioUnit,
        //                                  kAudioUnitProperty_SetRenderCallback,
        //                                  kAudioUnitScope_Global,
        //                                  kOutputBus,
        //                                  &callbackStruct,
        //                                  sizeof(callbackStruct));
        //    checkStatus(status);
        
        // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
        flag = 0;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_ShouldAllocateBuffer,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &flag,
                                      sizeof(flag));
        
        // Allocate our own buffers (1 channel, 16 bits per sample, thus 16 bits per frame, thus 2 bytes per frame).
        // Practice learns the buffers used contain 512 frames, if this changes it will be fixed in processAudio.
        _tempBuffer.mNumberChannels = 1;
        _tempBuffer.mDataByteSize = 512 * 2;
        _tempBuffer.mData = malloc( 512 * 2 );
        
        // Initialise
        status = AudioUnitInitialize(audioUnit);
        checkStatus(status);
        
    }
    
    return self;
    
    
}
- (void)aacData:(NSData *)data{

//    unsigned char *byte = ( unsigned char *)[data bytes];
    
    [[RecordManager shareManager] send_rtmp_audio:data andLength:(uint32_t)data.length];
    
}
- (void) start {
    OSStatus status = AudioOutputUnitStart(audioUnit);
    checkStatus(status);
}


@end
