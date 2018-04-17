//
//  FAACDecoder.m
//  Pullstream
//
//  Created by clj on 16/10/20.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "FAACDecoder.h"
#include "faad.h"

typedef struct {
    NeAACDecHandle handle;
    int sample_rate;
    int channels;
    int bit_rate;
    bool is_init_dec;
}FAADContext;

@implementation FAACDecoder
{

    FAADContext *aacContext;

}

uint32_t _get_frame_length(const unsigned char *aac_header)
{
    uint32_t len = *(uint32_t *)(aac_header + 3);
    len = ntohl(len); //Little Endian
    len = len << 6;
    len = len >> 19;
    return len;
}

void *faad_decoder_create(int sample_rate, int channels, int bit_rate)
{
    NeAACDecHandle handle = NeAACDecOpen();
    if(!handle){
        printf("NeAACDecOpen failed\n");
        goto error;
    }
    NeAACDecConfigurationPtr conf = NeAACDecGetCurrentConfiguration(handle);
    if(!conf){
        printf("NeAACDecGetCurrentConfiguration failed\n");
        goto error;
    }
    
    conf->defSampleRate = sample_rate;
    conf->outputFormat = FAAD_FMT_16BIT;
    conf->dontUpSampleImplicitSBR = 1;
    NeAACDecSetConfiguration(handle, conf);
    
    FAADContext* ctx = malloc(sizeof(FAADContext));
    ctx->handle = handle;
    ctx->sample_rate = sample_rate;
    ctx->channels = channels;
    ctx->bit_rate = bit_rate;
    return ctx;
    
error:
    if(handle){
        NeAACDecClose(handle);
    }
    return NULL;
}

int faad_decode_frame(void *pParam, unsigned char *pData, int nLen, unsigned char **pPCM, size_t *outLen)
{
    
    FAADContext* pCtx = (FAADContext*)pParam;
    NeAACDecHandle handle = pCtx->handle;
    
    if (!pCtx->is_init_dec) {
        
        long res = NeAACDecInit(handle, pData, nLen, (unsigned long*)&pCtx->sample_rate, (unsigned char*)&pCtx->channels);
        
        if (res < 0) {
            pCtx->is_init_dec = false;
            printf("NeAACDecInit failed\n");
            return -1;
        }else{
            pCtx->is_init_dec = true;
        }
    }

    NeAACDecFrameInfo info;
    uint32_t framelen = _get_frame_length(pData);
    unsigned char *buf = (unsigned char *)NeAACDecDecode(handle, &info, pData, framelen);
    
    if (buf && info.error == 0) {
        if (info.samplerate == 44100) {
            //src: 2048 samples, 4096 bytes
            //dst: 2048 samples, 4096 bytes
            int tmplen = (int)info.samples * 16 / 8;
            if (tmplen!=0) {
               
                static char  pcm[1024*5] = {0};
                memset(pcm, 0, 1024*5);
                for(int i=0,j=0; i<4096 && j<2048; i+=4, j+=2)
                {
                    pcm[j]= buf[i];
                    pcm[j+1]= buf[i+1];
                }
                *pPCM = malloc(2048);
                memcpy(*pPCM, pcm, 2048);
                buf = NULL;
            }
            *outLen = tmplen/2;
        } else if (info.samplerate == 22050) {
            //src: 1024 samples, 2048 bytes
            //dst: 2048 samples, 4096 bytes
            short *ori = (short*)buf;
            short tmpbuf[info.samples * 2];
            int tmplen = (int)info.samples * 16 / 8 * 2;
            for (int32_t i = 0, j = 0; i < info.samples; i += 2) {
                tmpbuf[j++] = ori[i];
                tmpbuf[j++] = ori[i + 1];
                tmpbuf[j++] = ori[i];
                tmpbuf[j++] = ori[i + 1];
            }
            memcpy(pPCM,tmpbuf,tmplen);
            *outLen = tmplen;
        }else if(info.samplerate == 8000){
            //从双声道的数据中提取单通道
            for(int i=0,j=0; i<4096 && j<2048; i+=4, j+=2)
            {
                *pPCM[j]= buf[i];
                *pPCM[j+1]=buf[i+1];
            }
            *outLen = (unsigned int)info.samples;
        }
    } else {
        printf("NeAACDecDecode failed\n");
        free(buf);
        return -1;
    }
    buf = NULL;
    return 0;
}

void faad_decode_close(void *pParam)
{
    if(!pParam){
        return;
    }
    FAADContext* pCtx = (FAADContext*)pParam;
    if(pCtx->handle){
        NeAACDecClose(pCtx->handle);
    }
    free(pCtx);
}

- (instancetype)initCreateAACDecoderWithSample_rate:(int)sample_rate channels:(int)channels  bit_rate:(int)bit_rate{

    if (self = [super init]) {
        
        aacContext = faad_decoder_create(sample_rate, channels, bit_rate);
    
    }

    return self;

}

- (int)decoderAACFrameWithpData:(unsigned char *)pData nLen:(int)nLen pPCM:(unsigned char **)pPCM outLen:(size_t *)outLen{
    
    add_adts_header(pData, nLen);

    FAADContext* pCtx = aacContext;

    return faad_decode_frame(pCtx, pData, nLen, &*pPCM, outLen);

}

-(int)decodeAudioAACFrameData:(AudioCompressData*)audioCompressData pcmData:(MediaFrame *__autoreleasing*)audioModel
{
    
    MediaFrameType mediaFrame = {0};
    mediaFrame.frame_duration = 0.023;
    mediaFrame.frame_pts = audioCompressData.timeStamp*0.001;
    mediaFrame.media_type = AUDIO_Type;
   
    int result = [self decoderAACFrameWithpData:(unsigned char*)audioCompressData.buffer nLen:audioCompressData.dataSize pPCM:&mediaFrame.audio_frame_data outLen:&mediaFrame.frame_size];
    if (mediaFrame.audio_frame_data != NULL) {
        *audioModel = [MediaFrame createFrameWithInfo:mediaFrame];

    }else{
        *audioModel = nil;
    }
    
    return result;
}

- (void)colseDecoder{

    faad_decode_close(aacContext);
    

}

static void add_adts_header(unsigned char *p, int es_len) {
    int frame_len = es_len;
    static int m_channel = 1; // 双声道
    static int m_profile = 1; // AAC(Version 4) LC
    static int m_sampleRateIndex = 4;
    
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


@end
