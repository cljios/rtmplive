//
//  AudioPlayer.m
//  Pullstream
//
//  Created by clj on 16/10/23.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "AudioPlayer.h"
#define kOutputBus 0
#define kInputBus 1
#define MAX_FRAME_SIZE 2048
#define MAX_CHAN       1
@implementation AudioPlayer
{
    AudioComponentInstance audioUnit;
    
    float                       *_outData;

}
-(instancetype) init {
    self = [super init];
    if (!self) return self;
    _outData = (float *)calloc(MAX_FRAME_SIZE*MAX_CHAN, sizeof(float));

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
//    status = AudioUnitSetProperty(audioUnit,
//                                  kAudioOutputUnitProperty_EnableIO,
//                                  kAudioUnitScope_Input,
//                                  kInputBus,
//                                  &flag,
//                                  sizeof(flag));
//    checkStatus(status);
    
    // Enable IO for playback
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  kOutputBus,
                                  &flag,
                                  sizeof(flag));
    checkStatus(status);
        // Describe format
    AudioStreamBasicDescription audioFormat = {0};
    audioFormat.mSampleRate                 = 44100.00;
    audioFormat.mFormatID                   = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags                = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket    = 1;
    audioFormat.mChannelsPerFrame   = 1;
    audioFormat.mBitsPerChannel             = 16;
    audioFormat.mBytesPerPacket             = 2;
    audioFormat.mBytesPerFrame              = 2;
    
    // Apply format
//    status = AudioUnitSetProperty(audioUnit,
//                                  kAudioUnitProperty_StreamFormat,
//                                  kAudioUnitScope_Output,
//                                  kInputBus,
//                                  &audioFormat,
//                                  sizeof(audioFormat));
    checkStatus(status);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &audioFormat,
                                  sizeof(audioFormat));
    checkStatus(status);
    
    
    // Set input callback
//    AURenderCallbackStruct callbackStruct;
//    callbackStruct.inputProc = recordingCallback;
//    callbackStruct.inputProcRefCon = self;
//    status = AudioUnitSetProperty(audioUnit,
//                                  kAudioOutputUnitProperty_SetInputCallback,
//                                  kAudioUnitScope_Global,
//                                  kInputBus,
//                                  &callbackStruct,
//                                  sizeof(callbackStruct));
    checkStatus(status);
    
    // Set output callback
    AURenderCallbackStruct callbackStruct;

    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus(status);
    
    // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
    flag = 0;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_ShouldAllocateBuffer,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &flag, 
                                  sizeof(flag));
    checkStatus(status);

    // TODO: Allocate our own buffers if we want
    
    // Initialise
    status = AudioUnitInitialize(audioUnit);
    checkStatus(status);
    
    return self;
}
/**
 This callback is called when the audioUnit needs new data to play through the
 speakers. If you don't have any, just don't write anything in the buffers
 */

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    // Notes: ioData contains buffers (may be more than one!)
    // Fill them up as much as you can. Remember to set the size value in each buffer to match how
    // much data is in the buffer.
    
    AudioPlayer *player = (__bridge AudioPlayer*)inRefCon;
    
    [player processAudioWithinNumberFrames:inNumberFrames ioData:ioData];
    
    
    
    return noErr;
}

- (void)processAudioWithinNumberFrames:(UInt32)numFrames ioData:(AudioBufferList *)ioData{
    @autoreleasepool {
        
        for (int i = 0 ;i < ioData->mNumberBuffers;++i) {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
        
        if (_outputBlock) {
            {
                
                _outputBlock(_outData, numFrames, 1);
                
                //            float scale = (float)INT16_MAX;
                //            vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*1);
                
#ifdef DUMP_AUDIO_DATA
                LoggerAudio(2, @"Buffer %u - Output Channels %u - Samples %u",
                            (uint)ioData->mNumberBuffers, (uint)ioData->mBuffers[0].mNumberChannels, (uint)numFrames);
#endif
                
                for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                    
//                    int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                    memcpy(ioData->mBuffers[iBuffer].mData, _outData, 1024);
                    //                for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                    //                    vDSP_vfix16(_outData+iChannel, 1, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
                    //                }
#ifdef DUMP_AUDIO_DATA
                    dumpAudioSamples(@"Audio frames decoded by FFmpeg and reformatted:\n",
                                     ((SInt16 *)ioData->mBuffers[iBuffer].mData),
                                     @"% 8d ", numFrames, thisNumChannels);
#endif
                }
                
            }
            
        }
    }
        
}

- (void) start{
    OSStatus status = AudioOutputUnitStart(audioUnit);
    checkStatus(status);
}

- (void) stop{
    OSStatus status = AudioOutputUnitStop(audioUnit);
    checkStatus(status);
    status = AudioComponentInstanceDispose(audioUnit);
    checkStatus(status);

}

- (void) processAudio: (AudioBufferList*) bufferList{

}
void checkStatus(int status){
    if (status) {
        printf("Status not 0! %d\n", status);
        //        exit(1);
    }
}

@end
