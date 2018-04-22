//
//  Converter.h
//  RtmpPlayer
//
//  Created by clj on 16/9/26.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AACEncodeDelegate <NSObject>

- (void)aacData:(unsigned char *)data datalen:(uint32_t)len;

@end

@interface Converter : NSObject
{
    AudioConverterRef m_converter;

}
@property (nonatomic,weak) id <AACEncodeDelegate> delegate;

@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) UInt32 aacBufferSize;
@property (nonatomic) uint8_t *pcmBuffer;
@property (nonatomic) UInt32 pcmBufferSize;
-(BOOL)encoderAAC:(AudioStreamBasicDescription)inputFormats  pcmData:(char*)pcmData pcmLen:(uint32_t)pcmLen;
@end
