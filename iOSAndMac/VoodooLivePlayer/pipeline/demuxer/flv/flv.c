//
//  flv.c
//  live_player
//
//  Created by voodoo on 2019/12/6.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

#include "flv.h"
#include "pt.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define VOODOO_READ_STATE_INIT       0
#define VOODOO_READ_STATE_PROBE      1
#define VOODOO_READ_STATE_HEADER     2
#define VOODOO_READ_STATE_PRE_TAG    3
#define VOODOO_READ_STATE_NEW_TAG    4
#define VOODOO_READ_STATE_TAG_HEADER 5
#define VOODOO_READ_STATE_TAG_BODY   6

#define VOODOO_STREAM_CACHE_SIZE    (8*1024*1024)
#define VOODOO_STREAM_PADDING_SIZE  (128)


typedef struct flv_demuxer_context_s {
    void *userdata;
    fn_demuxer_callback_t callback;
    
    int is_running;
    
    ptc_t ptc;
    
    int read_state;
    pts_t stream;
    
    /*
     video and audio config
     */
    int audio_codec_id;
    int audio_channels;
    int audio_sample_rate;
    int audio_bits_per_sample;
    
    int video_codec_id;
    int video_width;
    int video_height;
    int video_frame_format;
    
    
    int64_t stream_start;
    int64_t stream_end;

    uint32_t tmp32;

    uint8_t file_flag;
    uint8_t tag_type;
    uint32_t tag_size;
    uint32_t tag_start;
    int64_t tag_pos;
    int tag_encrypted;

    int last_audio_sample_rate;
    int last_audio_channels;

    int32_t wrong_dts;
    union {
        struct {
            int64_t pts, dts;
        };
        int64_t ts[2];
    };
    
    int64_t first_dts;
    int skip_frames;
    int seek_to_next_i_frame;
    
    uint64_t frame_count;
} flv_demuxer_context_t;

void* flv_demuxer_init(void* userdata, fn_demuxer_callback_t callback) {
    flv_demuxer_context_t* ctx = (flv_demuxer_context_t*)malloc(sizeof(flv_demuxer_context_t) + VOODOO_STREAM_CACHE_SIZE + VOODOO_STREAM_PADDING_SIZE);
    
    memset(ctx, 0, sizeof(flv_demuxer_context_t));
    
    ctx->userdata = userdata;
    ctx->callback = callback;
    
    ctx->dts = ctx->pts = ctx->first_dts = VOODOO_NOPTS_VALUE;
    
    ctx->stream.buf = (uint8_t*)(ctx+1);
    ctx->stream.pos = ctx->stream.size = 0;

    PT_INIT(&ctx->ptc, ctx);
    ctx->is_running = 1;
    ctx->read_state = VOODOO_READ_STATE_INIT;

    printf("FLV DEMUXER INITED!\n");
    
    return (void*)ctx;
}

void flv_demuxer_fint(void* ctx) {
    flv_demuxer_context_t* demuxer_ctx = (flv_demuxer_context_t*)ctx;
    demuxer_ctx->is_running = 0;
    demuxer_ctx->stream.buf = NULL;
    demuxer_ctx->stream.pos = demuxer_ctx->stream.size = 0;
    demuxer_ctx->userdata = NULL;
    free(ctx);
    printf("FLV DEMUXER FINTED!\n");
}

void flv_demuxer_seek_to_next_i_frame(void* ctx) {
    flv_demuxer_context_t* demuxer_ctx = (flv_demuxer_context_t*)ctx;
    demuxer_ctx->seek_to_next_i_frame = 1;
}

void flv_demuxer_set_skip_frames(void* ctx, int skip) {
    flv_demuxer_context_t* demuxer_ctx = (flv_demuxer_context_t*)ctx;
    demuxer_ctx->skip_frames = skip;
}

static int flv_demux_parse_stream(ptc_t* ptc);

int flv_demuxer_feed(void* ctx, const void* data, int len) {
    flv_demuxer_context_t *state = (flv_demuxer_context_t*)ctx;
    if(!state->is_running) {
        fprintf(stderr, "FLV DEMUXER IS ABORTED.\n");
        return -1;
    }
    /*
    ++_voodoo_decode_times;
    if((_voodoo_decode_times % 100) == 0 &&
       _voodoo_check_timeout() < 0) {
        printf("VOODOO IS ABORTED.\n");
        return -1;
    }
     */
    
    //printf("VOODOO DECODE: (%u)[%u]\n", data, len);

    int ret;
    pts_t *stream = &state->stream;
    uint32_t cache_space, copy_len;

    for(;;) {
        cache_space = VOODOO_STREAM_CACHE_SIZE - stream->size;
        if(cache_space == 0) {
            fprintf(stderr, "VOODOO STREAM CACHE SIZE[%u] IS TOO SAMLL FOR DECODING...\n", (uint32_t)VOODOO_STREAM_CACHE_SIZE);
            return -1;
        }

        copy_len = VPMIN(cache_space, (uint32_t)len);
        memcpy(stream->buf + stream->size, data, copy_len);

        stream->size += copy_len;
        state->stream_end += copy_len;

        memset(stream->buf + stream->size, 0, VOODOO_STREAM_PADDING_SIZE);

        ret = flv_demux_parse_stream(&state->ptc);

        if(ret == PTR_ERROR) {
            state->is_running = 0;
            return -1;
        } else if(ret == PTR_FINISHED) {
            printf("VOODOO FINISHED!\n");
            state->is_running = 0;
            return 0;
        } else if(stream->pos == 0 && len > copy_len) {
            fprintf(stderr, "VOODOO STREAM CACHE SIZE[%u] IS TOO SMALL\n", (uint32_t) VOODOO_STREAM_CACHE_SIZE);
            state->is_running = 0;
            return -1;
        }
        /*
         * 有消耗的数据，直接移出stream。
         */
        if(stream->pos > 0) {
            if(stream->pos < stream->size) {
                stream->size -= stream->pos;
                memmove(stream->buf, stream->buf + stream->pos, stream->size);
                state->stream_start += stream->pos;
                stream->pos = 0;
            } else {
                state->stream_start = state->stream_end;
                stream->size = stream->pos = 0;
            }
        }

        len -= copy_len;
        if(len == 0) {
            break;
        }
        data += copy_len;
    }
    return 0;
    return 0;
}

static void voodoo_show_hex(const char* title, const uint8_t *buf, uint32_t len) {
    printf("(%s) {", title);
    for(uint32_t u = 0;u < len; ++u) {
        if((u % 64 == 0)) {
           printf("\n");
        }
        printf("%02x ", buf[u]);
    }
    printf("\n}\n");
}

static int voodoo_parse_audio_tag(flv_demuxer_context_t *state);
static int voodoo_parse_video_tag(flv_demuxer_context_t *state);

static int flv_demux_parse_stream(ptc_t* ptc) {
    flv_demuxer_context_t* state = PT_DATA(ptc);
    pts_t* s = &state->stream;
    uint32_t tmp32;
    PT_BEGIN(ptc);
    {
        /*
            read probe
         */
        {
            state->read_state = VOODOO_READ_STATE_PROBE;
            PS_SR_BUF(s,&tmp32, 4);
            if(strncmp((char*)&tmp32, "FLV", 3) != 0) {
                voodoo_show_hex("NO SIGNATURE", s->buf, VPMIN(64,s->size));
                PT_THROW_ERROR(ptc, "NO FLV FILE SIGNATURE");
            }
            if(((uint8_t *)&tmp32)[3] != 0x01) {
                voodoo_show_hex("NO SIGNATURE", s->buf, VPMIN(64,s->size));
                PT_THROW_ERROR(ptc, "FLV FILE TYPE NOT 0X01");
            }
        }

        {
            state->read_state = VOODOO_READ_STATE_HEADER;
            PS_SR_U8(s,state->file_flag);
            printf("FILE FLAG READ, %s, %s\n", (state->file_flag & 4) != 0 ? "HAS AUDIO" : "NO AUDIO", (state->file_flag & 1) != 0 ? "HAS VIDEO" : "NO VIDEO" );
            
            //uint8_t flag_array[2] = { ((state->file_flag & 1) != 0 ? 1 : 0), ((state->file_flag & 4) != 0 ? 1 : 0) };

            /*
             callback media flags
             */
            state->callback(state->userdata, VOODOO_DATA_TYPE_MEDIA_FLAG, NULL, 0, NULL, (uint32_t)state->file_flag);

            PS_SR_U32(s,state->tmp32);
            if(state->tmp32 < 9) PT_THROW_ERROR(ptc, "offset less than 9");
            PS_SR_SKIP(s,state->tmp32-9);
        }

        {
            state->read_state = VOODOO_READ_STATE_PRE_TAG;
            //  prev tag size, must be zero
            PS_SR_U32(s,state->tmp32);
            if(state->tmp32 != 0) PT_THROW_ERROR(ptc, "prev tag size not zero");

            while(state->is_running) {
                state->read_state = VOODOO_READ_STATE_NEW_TAG;
                PS_SR_U8(s, state->tag_type);
                /*
                 parse encrypt flag
                 */
                if((state->tag_type & 0xc0) != 0) PT_THROW_ERROR(ptc, "Reserved for FMS is not zero");
                state->tag_encrypted = ((state->tag_type & 0x20) != 0);
                state->tag_type &= 0x1f;
                
                PS_SR_U24(s, state->tag_size);
                if(state->tag_type != 8 &&
                   state->tag_type != 9 &&
                   state->tag_type != 18) {
                    PS_SR_SKIP(s,state->tag_size+11);
                    continue;
                }
                state->read_state = VOODOO_READ_STATE_TAG_HEADER;
                //  timestamp
                PS_SR_U24(s, state->tmp32);
                uint8_t ts3;
                PS_SR_U8(s,ts3);
                state->tmp32 |= ((uint32_t)ts3) << 24;
                state->dts = state->tmp32;
                /*
                if(state->first_dts == VOODOO_NOPTS_VALUE) {
                    state->first_dts = state->dts;
                    state->dts -= state->first_dts;
                } else {
                    state->dts -= state->first_dts;
                }
                */
                //printf("TAGTYPE %d TAG DTS: %"PRId64"\n", (int)state->tag_type, state->dts);

                //  stream id
                PS_SR_U24(s, state->tmp32);
                if(state->tmp32 != 0) {
                    fprintf(stderr, "[WARN] stream id %u is not zero\n", state->tmp32);
                }
                state->read_state = VOODOO_READ_STATE_TAG_BODY;
                /**
                 * todo: 这里后面应改为按照流模式读取，不使用ENSURE。避免一个tag的大小超过STREAM CACHE的情况。
                 */
                PS_ENSURE(s,state->tag_size);
                state->tag_start = s->pos;
                state->tag_pos = state->tag_start + state->stream_start;
                if(state->tag_type == 8) {
                    if(voodoo_parse_audio_tag(state) < 0) {
                        fprintf(stderr, "[WARN] parse audio data failed\n");
                    }
                } else if(state->tag_type == 9) {
                    if(voodoo_parse_video_tag(state) < 0) {
                        fprintf(stderr, "[WARN] parse video data failed\n");
                    }
                } else if(state->tag_type == 18) {
                    fprintf(stderr, "[WARN] SKIP SCRIPT DATA\n");
                } else {
                    fprintf(stderr,"[WARN] UNSUPPORTED TAG [%d]\n", (int) state->tag_type);
                }
                s->pos = state->tag_start + state->tag_size;
                //  prev tag size
                PS_SR_U32(s,state->tmp32);
                if(state->tmp32 != 11 + state->tag_size) {
                    fprintf(stderr, "[WARN] Invalid PreTagSize: %u\n", state->tmp32);
                }
            }
        }
    }
    PT_END(ptc);
}

/* offsets for packed values */
#define FLV_AUDIO_SAMPLESSIZE_OFFSET 1
#define FLV_AUDIO_SAMPLERATE_OFFSET  2
#define FLV_AUDIO_CODECID_OFFSET     4

#define FLV_VIDEO_FRAMETYPE_OFFSET   4

/* bitmasks to isolate specific values */
#define FLV_AUDIO_CHANNEL_MASK    0x01
#define FLV_AUDIO_SAMPLESIZE_MASK 0x02
#define FLV_AUDIO_SAMPLERATE_MASK 0x0c
#define FLV_AUDIO_CODECID_MASK    0xf0

#define FLV_AUDIO_MONO      0
#define FLV_AUDIO_STEREO    1

static int voodoo_parse_audio_tag(flv_demuxer_context_t *state) {
    if(state->tag_size < 2) {
        fprintf(stderr, "TAG SIZE IS TOO SMALL FOR VIDEO TAG\n");
        return -1;
    }
    
    pts_t stream = { state->stream.buf + state->stream.pos, state->tag_size, 0};
    pts_t *s = &stream;

    PS_DR_U8(s);
    uint8_t packetType = PS_DR_U8(s);
    
    if(state->tag_size == 2) { return 0; }
    if(packetType == 0) {
        /*
         parameters need whole tag
         */
        state->callback(state->userdata, VOODOO_DATA_TYPE_AUDIO_PARAMETERS, s->buf + s->pos, s->size - 2, state->ts, 0);
    } else {
        if(state->skip_frames ||
           state->seek_to_next_i_frame) {
            return 0;
        }
        state->callback(state->userdata, VOODOO_DATA_TYPE_AUDIO_PACKET, s->buf + s->pos, s->size - 2, state->ts, 0);
    }
    return 0;
}

#define FLV_FRAME_KEY            1 ///<< FLV_VIDEO_FRAMETYPE_OFFSET, ///< key frame (for AVC, a seekable frame)
#define FLV_FRAME_INTER          2 ///<< FLV_VIDEO_FRAMETYPE_OFFSET, ///< inter frame (for AVC, a non-seekable frame)
#define FLV_FRAME_DISP_INTER     3 ///<< FLV_VIDEO_FRAMETYPE_OFFSET, ///< disposable inter frame (H.263 only)
#define FLV_FRAME_GENERATED_KEY  4 ///<< FLV_VIDEO_FRAMETYPE_OFFSET, ///< generated key frame (reserved for server use only)
#define FLV_FRAME_VIDEO_INFO_CMD 5 ///<< FLV_VIDEO_FRAMETYPE_OFFSET, ///< video info/command frame

#define FLV_VIDEO_CODECID_MASK    0x0fU
#define FLV_VIDEO_FRAMETYPE_MASK  0xf0U

//#define VOODOO_NOPTS_VALUE  ((int64_t)UINT64_C(0x8000000000000000))

static int voodoo_parse_video_tag(flv_demuxer_context_t *state) {
    if(state->tag_size < 5) {
        fprintf(stderr, "TAG SIZE IS TOO SMALL FOR VIDEO TAG\n");
        return -1;
    }
    
    pts_t stream = { state->stream.buf + state->stream.pos, state->tag_size, 0};
    pts_t *s = &stream;
    
    uint8_t spec = PS_DR_U8(s);

    uint8_t frame_type = (spec & (uint8_t )FLV_VIDEO_FRAMETYPE_MASK) >> 4;
    uint8_t video_codec = spec & (uint8_t )FLV_VIDEO_CODECID_MASK;

    if(video_codec != 7) {
        fprintf(stderr, "unsupported video codec %u\n", (uint32_t) video_codec);
        return -1;
    }

    if(frame_type == FLV_FRAME_VIDEO_INFO_CMD) {
        return 0;
    }

    uint8_t packetType = PS_DR_U8(s);
    int32_t cts = (PS_DR_U24(s) + 0xff800000) ^ 0xff800000;
    state->pts = state->dts + cts;
    if (cts < 0) { // dts might be wrong
        if (!state->wrong_dts)
            state->wrong_dts = 1;
    } else if (VPABS(state->dts - state->pts) > 1000*60*15) {
        state->dts = state->pts = VOODOO_NOPTS_VALUE;
    }
    
    if(state->tag_size == 5) {
        return 0;
    }

    if(packetType == 0) {// AVCDecoderConfigurationRecord
        state->callback(state->userdata, VOODOO_DATA_TYPE_VIDEO_PARAMETERS, s->buf + s->pos, state->tag_size - 5, state->ts, (uint32_t)video_codec);
    } else if(packetType == 1) {// One or more Nalus
        
        if (frame_type == FLV_FRAME_KEY) {
            //printf("KEY FRAME AT %llu\n", state->frame_count);
        }
        
        ++state->frame_count;
        
        /*
            跳帧，直接返回，不解析
        */
        if(state->skip_frames) {
            return 0;
        }
        /*
            seek到下一个i帧
        */
        if(state->seek_to_next_i_frame) {
            if(frame_type != FLV_FRAME_KEY) {
                return 0;
            }
            state->seek_to_next_i_frame = 0;
        }
        
        /*
         todo: need to fix leading bytes for android muxer
         */
        state->callback(state->userdata, VOODOO_DATA_TYPE_VIDEO_PACKET, s->buf + s->pos, state->tag_size - 5, state->ts, frame_type == FLV_FRAME_KEY ? VOODOO_VIDEO_PACKET_FLAG_IS_KEY_FRAME : 0);
        
        
    } else if(packetType == 2) {
        return 0;
    } else {
        return -1;
    }
    return 0;
}
