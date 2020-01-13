//
//  demuxer.h
//  QLive
//
//  Created by voodoo on 2019/12/7.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

#ifndef demuxer_h
#define demuxer_h

#include <stdint.h>

typedef void (*fn_demuxer_callback_t)(void* userdata, int type, void* data, int size, int64_t ts[], uint32_t flag);
#define VPMIN(a,b)   ((a)<(b)?(a):(b))
#define VPMAX(a,b)   ((a)<(b)?(b):(a))

#define VPABS(a) ((a)<0?(-(a)):(a))

#define VOODOO_DATA_TYPE_RAW_DATA           0
#define VOODOO_DATA_TYPE_MEDIA_FLAG         1
//#define VOODOO_DATA_TYPE_SPS_AND_PPS        1
#define VOODOO_DATA_TYPE_VIDEO_PARAMETERS   2
#define VOODOO_DATA_TYPE_VIDEO_PACKET       3
//#define VOODOO_DATA_TYPE_VIDEO_CONFIG       4
#define VOODOO_DATA_TYPE_AUDIO_PARAMETERS   4
#define VOODOO_DATA_TYPE_AUDIO_PACKET       5
//#define VOODOO_DATA_TYPE_AUDIO_CONFIG       7

#define VOODOO_VIDEO_PACKET_FLAG_IS_KEY_FRAME   1

//#define VOODOO_NOPTS_VALUE  ((int64_t)UINT64_C(0x8000000000000000))
#define VOODOO_NOPTS_VALUE                  ((int64_t)-9223372036854775807LL)

#endif /* demuxer_h */
