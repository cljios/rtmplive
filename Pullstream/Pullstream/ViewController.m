//
//  ViewController.m
//  Pullstream
//
//  Created by clj on 16/9/12.
//  Copyright © 2016年 clj. All rights reserved.
//
#import "ViewController.h"
#import "AAPLEAGLLayer.h"
#import "MediaManager.h"
#import "MediaManager.h"
#import "AudioClock.h"
@interface ViewController ()
{
    int bufsize;
    char *buf;
    
    AAPLEAGLLayer *_glLayer;
    AudioPlayer *_audioPlayer;
    MediaManager *_mediaManager;
    AudioClock *_audioClockTime;

    NSThread *thread1;
    NSThread *thread2;
    NSThread *thread3;

    NSData *_currentAudioFrame;
    NSUInteger _currentAudioFramePos;
    BOOL isPlayingVideo;
    BOOL isPlayingAudio;
    BOOL isTiming;

}
- (IBAction)startConnect:(id)sender;
- (IBAction)pullstream:(id)sender;
- (IBAction)startPlay:(id)sender;

@end


@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];


    _glLayer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.bounds];
    [self.view.layer addSublayer:_glLayer];
    
    _mediaManager = [MediaManager new];
    
    [_mediaManager profileAudioSession];
    
    _audioPlayer = [AudioPlayer new];
    
    _audioClockTime = [AudioClock new];
    
    _currentAudioFramePos = 0;

}

-(void)threadFun3{
    
    
//    while (1) {
//        if (isPlaying) {
//            [_audioPlayer start];
//            break;
//        }else{
//            continue;
//        }
//    }
//    [[NSThread currentThread] setName:@"changzhuThread"];
//    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
//    //// 这里主要是监听某个 port，目的是让这个 Thread 不会回收
//    [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
//    [runLoop run];

}
- (void)audioCallbackFillData:(float *)outData numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels{

    if (isTiming == NO) {
        isTiming = YES;
        [_audioClockTime startTiming];
    }else{
        [_audioClockTime endTiming];
        UInt64 lastTime = [_audioClockTime calculateTime];
        isTiming = NO;
        NSLog(@"音频播放时间lastTime:%llu",lastTime);
    }
    
    
    @autoreleasepool {
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {

                MediaFrame *frame = [_mediaManager playAudioFrame];
                
                if (frame) {
                    _currentAudioFrame = [NSData dataWithBytes:frame->_frame_info.audio_frame_data length:frame->_frame_info.frame_size];
                    frame = nil;
                }
                _currentAudioFramePos = 0;

            }
            
            if (_currentAudioFrame) {
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(SInt16);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;
                
            }else {
                memset(outData, 0, numFrames * numChannels * sizeof(SInt16));
                break;
            }
        }
    }
    
//    if (frame) {
//        memcpy(data, frame->_frame_info.audio_frame_data, frame->_frame_info.frame_size);
//    }
//    frame = nil;

}
- (void)threadFun1{
    
    __weak typeof(self) ws = self;
    _audioPlayer.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels){
        [ws audioCallbackFillData: data numFrames:numFrames numChannels:numChannels];
    };
    
    while (1) {
        
        @autoreleasepool {
            if (isPlayingVideo) {
                
                if (isPlayingAudio) {
                    isPlayingAudio = NO;
                    [_audioPlayer start];
                }
                NSArray *videoFrames = [_mediaManager presentVideoFrame];
                if (videoFrames .count > 0) {
                    [self performSelectorOnMainThread:@selector(MainThread:) withObject:videoFrames waitUntilDone:YES];
                }else{
                    videoFrames = nil;
                }
                
            }else{
                sleep(0);
            }
        }
        
        
    }
}
- (void)MainThread:(NSArray *)videoFrames{
   
    @autoreleasepool {
        CGFloat sleep_time = 0.011/videoFrames.count;
        for (int i =0; i < videoFrames.count; ++i) {
            MediaFrame *frame = [videoFrames objectAtIndex:i];
            _glLayer.pixelBuffer = frame->_frame_info.video_frame_data;
            frame = nil;
            [NSThread sleepForTimeInterval:sleep_time];
            
        }
    }
    
}
- (void)threadFun2{
    
    [_mediaManager decodeFrame];
    
//    RTMPPacket pc = { 0 }, ps = { 0 };
//    bool bFirst = true;
//    while (RTMP_ReadPacket(rtmp, &pc))
//    {
//        if (RTMPPacket_IsReady(&pc))
//        {
//            if (pc.m_packetType == RTMP_PACKET_TYPE_VIDEO && RTMP_ClientPacket(rtmp, &pc))
//            {
//                bool bIsKeyFrame = false;
//                if (result == 0x17)//I frame
//                {
//                    bIsKeyFrame = true;
//                }
//                else if (result == 0x27)
//                {
//                    bIsKeyFrame = false;
//                }
//                static unsigned char const start_code[4] = {0x00, 0x00, 0x00, 0x01};
//                fwrite(start_code, 1, 4, pf );
//                //int ret = fwrite(pc.m_body + 9, 1, pc.m_nBodySize-9, pf);
//                
//                
//                if( bFirst) {
//                    
//                    
//                    //AVCsequence header
//                    
//                    
//                    //ioBuffer.put(foredata);
//                    
//                    
//                    //获取sps
//                    
//                    
//                    int spsnum = data[10]&0x1f;
//                    
//                    
//                    int number_sps = 11;
//                    
//                    
//                    int count_sps = 1;
//                    
//                    
//                    while (count_sps<=spsnum){
//                        
//                        
//                        int spslen =(data[number_sps]&0x000000FF)<<8 |(data[number_sps+1]&0x000000FF);
//                        
//                        
//                        number_sps += 2;
//                        
//                        
//                        fwrite(data+number_sps, 1, spslen, pf );
//                        fwrite(start_code, 1, 4, pf );
//                        
//                        
//                        //ioBuffer.put(data,number_sps, spslen);
//                        //ioBuffer.put(foredata);
//                        
//                        
//                        number_sps += spslen;
//                        
//                        
//                        count_sps ++;
//                        
//                        
//                    }
//                    
//                    
//                    //获取pps
//                    
//                    
//                    int ppsnum = data[number_sps]&0x1f;
//                    
//                    
//                    int number_pps = number_sps+1;
//                    
//                    
//                    int count_pps = 1;
//                    
//                    
//                    while (count_pps<=ppsnum){
//                        
//                        
//                        int ppslen =(data[number_pps]&0x000000FF)<<8|data[number_pps+1]&0x000000FF;
//                        
//                        
//                        number_pps += 2;
//                        
//                        
//                        //ioBuffer.put(data,number_pps,ppslen);
//                        
//                        
//                        //ioBuffer.put(foredata);
//                        
//                        
//                        fwrite(data+number_pps, 1, ppslen, pf );
//                        fwrite(start_code, 1, 4, pf );
//                        
//                        
//                        number_pps += ppslen;
//                        
//                        
//                        count_pps ++;
//                        
//                        
//                    }
//                    
//                    
//                    bFirst =false;
//                    
//                    
//                } else {
//                    
//                    
//                    //AVCNALU
//                    
//                    
//                    int len =0;
//                    
//                    
//                    int num =5;
//                    
//                    
//                    //ioBuffer.put(foredata);
//                    
//                    
//                    while(num {
//                        
//                        
//                        len =(data[num]&0x000000FF)<<24|(data[num+1]&0x000000FF)<<16|(data[num+2]&0x000000FF)<<8|data[num+3]&0x000000FF;
//                        
//                        
//                        num = num+4;
//                        
//                        
//                        //ioBuffer.put(data,num,len);
//                        
//                        
//                        //ioBuffer.put(foredata);
//                        
//                        
//                        fwrite(data+num, 1, len, pf );
//                        fwrite(start_code, 1, 4, pf );
//                        
//                        
//                        num = num + len;
//                        
//                        
//                    }
//                          
//                          
//                          }       
//                          
//                          
//                          }
//                       
//                          }
    
//    RTMP_GetNextMediaPacket(<#RTMP *r#>, <#RTMPPacket *packet#>)
    return;
    
}


#pragma mark 开始拉流
- (IBAction)pullstream:(id)sender {
    
    thread2  = [[NSThread alloc] initWithTarget:self selector:@selector(threadFun2) object:nil];
    [thread2  setName:@"线程2"];
    [thread2  start];
    
    thread1  = [[NSThread alloc] initWithTarget:self selector:@selector(threadFun1) object:nil];
    [thread1  setName:@"线程1"];
    [thread1  start];
}

- (IBAction)startPlay:(id)sender {

    isPlayingAudio = isPlayingVideo = YES;
}
- (IBAction)startConnect:(id)sender {
    
    [_mediaManager connectRtmpSever:"rtmp://192.168.1.186:1935/rtmplive/room"];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
