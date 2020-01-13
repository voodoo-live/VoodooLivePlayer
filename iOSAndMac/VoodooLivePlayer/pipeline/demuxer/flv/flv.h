//
//  flv.h
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/6.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

#ifndef flv_h
#define flv_h

#include "demuxer.h"

void* flv_demuxer_init(void* userdata, fn_demuxer_callback_t callback);
void flv_demuxer_fint(void* ctx);
int flv_demuxer_feed(void* ctx, const void* data, int len);

void flv_demuxer_seek_to_next_i_frame(void* ctx);
void flv_demuxer_set_skip_frames(void* ctx, int skip);

#endif /* flv_h */
