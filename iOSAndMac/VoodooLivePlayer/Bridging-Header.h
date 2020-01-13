//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include "demuxer.h"

void* flv_demuxer_init(void* userdata, fn_demuxer_callback_t callback);
void flv_demuxer_fint(void* ctx);
int flv_demuxer_feed(void* ctx, const void* data, int len);

