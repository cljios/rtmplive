//
//  H264Decoder.m
//  Pullstream
//
//  Created by clj on 16/9/13.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "H264Decoder.h"
@implementation H264Decoder
{
    VTDecompressionSessionRef _deocderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
    VIDEO_SPS_PPS_TYPE sps_pps;

}
static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    
//    NSLog(@"解码回调");
    
    
}
-(BOOL)initH264DecoderWithSPS:(char *)sps spslen:(uint32_t)spslen pps:(char *)pps ppslen:(uint32_t)ppslen{
    
    
    if(_deocderSession) {
        return YES;
    }
    if (sps_pps.sps) {
        free(sps_pps.sps);
    }
    if (sps_pps.pps) {
        free(sps_pps.pps);
    }
    sps_pps.spslen = spslen;
    sps_pps.sps = malloc(spslen);
    memcpy(sps_pps.sps, sps, spslen);
    sps_pps.ppslen = ppslen;
    sps_pps.pps = malloc(ppslen);
    memcpy(sps_pps.pps, pps, ppslen);
    
    const uint8_t* const parameterSetPointers[2] = { sps_pps.sps,  sps_pps.pps};
    const size_t parameterSetSizes[2] = { sps_pps.spslen, sps_pps.ppslen};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    if(status == noErr) {
        //        CFDictionaryRef attrs = NULL;
//        const void *keys[] = {kCVPixelBufferPixelFormatTypeKey};
        //              kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //              kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
//        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
//        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        //        kCFNumberCFIndexType
//        CFIndex index = (signed long)1;
        //        typedef struct {
        //            CFIndex				version;
        //            CFDictionaryRetainCallBack		retain;
        //            CFDictionaryReleaseCallBack		release;
        //            CFDictionaryCopyDescriptionCallBack	copyDescription;
        //            CFDictionaryEqualCallBack		equal;
        //            CFDictionaryHashCallBack		hash;
        //        } CFDictionaryKeyCallBacks;
        //        CFDictionaryKeyCallBacks keycallBacks;
        //        keycallBacks.retain = dictionaryKeyRetain;
        //        CFDictionaryValueCallBacks valuecallBacks;
        //        valuecallBacks.retain = dictionaryValueRetain;
        
        //        attrs = CFDictionaryCreate(NULL, keys, values, index, &keycallBacks, &valuecallBacks);
        
        
        
        
        
        NSDictionary* destinationPixelBufferAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],};
        
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;;
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL, (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
                                              &callBackRecord,
                                              &_deocderSession);
//                VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
//                VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
    }    return YES;
}

-(void)decodeVideoFrameData:(VideoCompressData*)vpkt YUVData:(MediaFrame **)videoModel{
    
    uint32_t nalSize = (uint32_t)(vpkt.dataSize-4);
    
    //方法1系统提供宏：主机字节序转换网络大端字节序
    
    NTOHL(nalSize);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    vpkt.buffer[0] = *(pNalSize + 0);
    vpkt.buffer[1] = *(pNalSize + 1);
    vpkt.buffer[2] = *(pNalSize + 2);
    vpkt.buffer[3] = *(pNalSize + 3);
    
    //方法2指针：主机字节序转换网络大端字节序
    
    //        vp.buffer[0] = *(pNalSize + 3);
    //        vp.buffer[1] = *(pNalSize + 2);
    //        vp.buffer[2] = *(pNalSize + 1);
    //        vp.buffer[3] = *(pNalSize);
    
    //方法3位运算：主机字节序转换网络大端字节序
    
    //        uint8_t arr[4] = {(nalSize >> 24),(nalSize >> 16),(nalSize >> 8 & 0xff),(nalSize)};
    //
    //        vp.buffer[0] = arr[0];
    //        vp.buffer[1] = arr[1];
    //        vp.buffer[2] = arr[2];
    //        vp.buffer[3] = arr[3];
    
    
    CVPixelBufferRef pixelBuffer = NULL;

    pixelBuffer = [self decode:vpkt];

    MediaFrameType mediaFrame = {0};
    mediaFrame.video_frame_data = pixelBuffer;
    mediaFrame.frame_duration = 0.04;
    mediaFrame.frame_pts = vpkt.timeStamp*0.001;
    mediaFrame.media_type = VIDEO_Type;
    *videoModel = [MediaFrame createFrameWithInfo:mediaFrame];

//    if (pixelBuffer) {
//    }else{
//    
//        *videoModel = nil;
//    }
    
    

}
-(void)clearH264Deocder {
    if(_deocderSession) {
        VTDecompressionSessionInvalidate(_deocderSession);
        CFRelease(_deocderSession);
        _deocderSession = NULL;
    }
    
    if(_decoderFormatDescription) {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
    
    free(sps_pps.pps);
    free(sps_pps.sps);
    sps_pps.ppslen = sps_pps.spslen = 0;
}

-(CVPixelBufferRef)decode:(VideoCompressData*)vpkt {
    
    
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                          (void *)vpkt.buffer,
                                                          vpkt.dataSize,
                                                          kCFAllocatorNull,
                                                          NULL,
                                                          0,
                                                          vpkt.dataSize,
                                                          FALSE,
                                                          &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {vpkt.dataSize};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
            }
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    return outputPixelBuffer;
}
@end
