//
//  FAACDecoder.h
//  Pullstream
//
//  Created by clj on 16/10/20.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MediaFrame.h"
#import "AudioCompressData.h"
void *faad_decoder_create(int sample_rate, int channels, int bit_rate);
int faad_decode_frame(void *pParam, unsigned char *pData, int nLen, unsigned char **pPCM, size_t *outLen);
void faad_decode_close(void *pParam);

@interface FAACDecoder : NSObject

- (instancetype)initCreateAACDecoderWithSample_rate:(int)sample_rate channels:(int)channels  bit_rate:(int)bit_rate;
-(int)decodeAudioAACFrameData:(AudioCompressData*)audioCompressData pcmData:(MediaFrame *__autoreleasing*)audioModel;
- (void)colseDecoder;
@end
