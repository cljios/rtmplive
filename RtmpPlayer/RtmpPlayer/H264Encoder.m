//
//  H264Encoder.m
//  RtmpPlayer
//
//  Created by clj on 16/8/17.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "H264Encoder.h"
#import <VideoToolbox/VideoToolbox.h>

#import "RecordManager.h"

@interface H264Encoder ()
{
    VTCompressionSessionRef  compressionSession;
    size_t  frameCount;
    dispatch_queue_t         aQueue;
    @public BOOL isHasPPS;
    
}
@end
void compressionOutputCallback(
                               void *  outputCallbackRefCon,
                               void *  sourceFrameRefCon,
                               OSStatus status,
                               VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer ){
    
//    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264Encoder* vc = (__bridge H264Encoder*)outputCallbackRefCon;
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey(
                                             (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe && !vc->isHasPPS) {
        
        vc->isHasPPS = YES;
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        
        
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found pps
                //                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                //                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                //                if (encoder->_delegate)
                //                {
                //                    [encoder->_delegate gotSpsPps:encoder->sps pps:encoder->pps];
                //                }
                
                
                //                uint8_t *space = (uint8_t *)malloc(sparameterSetSize +4);
                //
                //                memmove(space, startCode, 4);
                //
                //                memmove(space+4, sparameterSet, sparameterSetSize);
                //
                //
                //
                //                uint8_t *space2 = (uint8_t *)malloc(pparameterSetSize+4);
                //
                //                memmove(space2, startCode, 4);
                //
                //                memmove(space2+4, pparameterSet, pparameterSetSize);
                
                [vc.delegate spsData:[NSData dataWithBytes:sparameterSet length:sparameterSetSize] ppsData:[NSData dataWithBytes:pparameterSet length:pparameterSetSize]];
                

                
                //                [vc fileParser:(uint8_t*)sparameterSet length:(uint32_t)sparameterSetSize];
                //                [vc fileParser:(uint8_t *)pparameterSet length:(uint32_t)pparameterSetSize];
//                [[RecordManager shareManager] writeRecordData:[NSData dataWithBytes:sparameterSet length:sparameterSetSize]];
//                [[RecordManager shareManager] writeRecordData:[NSData dataWithBytes:pparameterSet length:pparameterSetSize]];

//                vc.frameNum = vc.frameNum+1;
//                NSLog(@"多少帧：%d",vc.frameNum);

            }
        }
        
    }
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
           vc.frameNum = vc.frameNum+1;
//            NSLog(@"多少帧：%d",vc.frameNum);
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            
//            [[RecordManager shareManager] writeRecordData:data];
            if (data.length > 0) {
                [vc.delegate fileNaludata:data iskeyF:keyframe];
            }
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
            
            
        }
        
    }
    
}
@implementation H264Encoder
- (instancetype)init{
    
    if (self =[super init]) {
        aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    return self;
}
- (void)initEncodeWidth:(int32_t)width height:(int32_t)height{
    // Create the compression session
    dispatch_sync(aQueue, ^{
        
        OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, compressionOutputCallback, (__bridge void *)self, &compressionSession);
        
        if (status != 0) {
            
            NSLog(@"H264: Unable to create a H264 session");
            
        }
        
        //        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval,(CFTypeRef)240);
        //
        //        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        //        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        //
        //        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_5_2);
        
        
        // Set the properties
        //            VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        //            VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        //            VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (CFTypeRef)1);
        //
        //            VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        
        
//        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
//        
//        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_5_2);
//        
//        
//        SInt32 bitRate = width*height*7.5;
//        CFNumberRef ref = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
//        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, ref);
//        CFRelease(ref);
//        //
//        
//        int frameInterval = 2; //关键帧间隔
//        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
//        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval,frameIntervalRef);
//        CFRelease(frameIntervalRef);
//
        
        // 设置实时编码输出，降低编码延迟
        status = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        NSLog(@"set realtime  return: %d", (int)status);
        
        // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
        status = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_4_0);
        NSLog(@"set profile   return: %d", (int)status);
        // 设置编码码率(比特率)，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊
        SInt32 bt = width*height*0.05;
        status  = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bt)); // bps
        status = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(bt/8), @(1)]); // Bps
        NSLog(@"set bitrate   return: %d", (int)status);
        
        // 设置关键帧间隔，即gop size
        int fps = 15;
        status = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(fps));
        
        // 设置帧率，只用于初始化session，不是实际FPS
        status = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(25));
        NSLog(@"set framerate return: %d", (int)status);
    
        // 开始编码
        VTCompressionSessionPrepareToEncodeFrames(compressionSession);
        NSLog(@"start encode  return: %d", (int)status);

    });
    
}

- (void)videoEncode:(CMSampleBufferRef)sampleBuffer{

    dispatch_sync(aQueue, ^{
        
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime presentationTimeStamp = CMTimeMake(frameCount, 1);
        CMTime duration = kCMTimeInvalid;

//        CMTime presentationTimeStamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
//        CMTime duration = CMSampleBufferGetOutputDuration(sampleBuffer);
//        double seconds = CMTimeGetSeconds(presentationTimeStamp);
//        NSLog(@"%lld-----%f",duration.value/duration.timescale,seconds);
        
        VTEncodeInfoFlags flags;
        
        OSStatus statusCode = VTCompressionSessionEncodeFrame(compressionSession, imageBuffer, presentationTimeStamp, duration, NULL, NULL, &flags);
        
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            //        error = @"H264: VTCompressionSessionEncodeFrame failed ";
            
            // End the session
            VTCompressionSessionInvalidate(compressionSession);
            CFRelease(compressionSession);
            compressionSession = NULL;
            return;
        }
        frameCount++;
        
    });
    
}

@end

