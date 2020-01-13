//
//  pt.h
//  QLive
//
//  Created by voodoo on 2019/12/7.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

#ifndef pt_h
#define pt_h

#include <inttypes.h>

typedef struct ptc_s {int lc;void *data;const char *error_msg;const char *error_file;int error_line;} ptc_t;
typedef struct pts_s { uint8_t *buf;uint32_t size;uint32_t pos; } pts_t;

#define PTR_ERROR                  (-1)
#define PTR_YIELDED                1
#define PTR_FINISHED               0
#define PT_DATA(ptc)               ((ptc)->data)
#define PT_INIT(ptc,_data)         do { (ptc)->lc = 0;(ptc)->data=(_data);} while(0)
#define PT_BEGIN(ptc)              switch((ptc)->lc) { case 0:
#define PT_END(ptc)                break; default: break; } (ptc)->lc = 0; return PTR_FINISHED;
#define PT_YIELD(ptc)              do {(ptc)->lc = __LINE__;return PTR_YIELDED;case __LINE__:;} while(0)
#define PT_THROW_ERROR(ptc, err)   do {(ptc)->error_msg = (err), (ptc)->error_file = __FILE__, (ptc)->error_line = __LINE__; fprintf(stderr, "[PT ERROR] %s @ %s[%d]\n", (err), __FUNCTION__, __LINE__); return PTR_ERROR;}while(0)


#define PS_PR_U8(s,_pos)           *((s)->buf+(s)->pos+(_pos))
#define PS_PR_U24(s,_pos)          ((((uint32_t)PS_PR_U8(s,(_pos))) << 16)|(((uint32_t)PS_PR_U8(s,(_pos)+1)) << 8)|((uint32_t)PS_PR_U8(s,(_pos)+2)))
#define PS_DR_U8(s)                *((s)->buf+(s)->pos++)
#define PS_DR_U16(s)               ((((uint16_t)PS_DR_U8(s)) << 8) | ((uint16_t)PS_DR_U8(s)))
#define PS_DR_U24(s)               ((((uint32_t)PS_DR_U8(s)) << 16)|(((uint32_t)PS_DR_U8(s)) << 8)|((uint32_t)PS_DR_U8(s)))
#define PS_DR_U32(s)               ((((uint32_t)PS_DR_U8(s)) << 24)|(((uint32_t)PS_DR_U8(s)) << 16)|(((uint32_t)PS_DR_U8(s)) << 8)|((uint32_t)PS_DR_U8(s)))
#define PS_DR_U64(s)               ((((uint64_t)PS_DR_U32(s)) << 32)|((uint64_t)PS_DR_U32(s)))
//static float PS_DR_F32(vpts_t *s)  { float f; *(uint32_t *) &f = PS_DR_U32(s); return f; }
//static double PS_DR_F64(vpts_t *s) { double d; *(uint64_t *) &d = PS_DR_U64(s); return d; }
#define PS_DR_BUF(s,_buf,_len)     memcpy((_buf), (s)->buf+(s)->pos, (_len)), (s)->pos += (_len)
#define PS_DR_SKIP(s,len)          ((s)->pos += (len))
#define PS_ENSURE(s,len)           while((s)->pos + (len) > (s)->size) {PT_YIELD(ptc);}
#define PS_SR_U8(s,ubv)            do { PS_ENSURE(s,1); (ubv) = PS_DR_U8(s); } while(0)
#define PS_SR_U16(s,usv)           do { PS_ENSURE(s,2); (usv) = PS_DR_U16(s); } while(0)
#define PS_SR_U24(s,uiv)           do { PS_ENSURE(s,3); (uiv) = PS_DR_U24(s); } while(0)
#define PS_SR_U32(s,uiv)           do { PS_ENSURE(s,4); (uiv) = PS_DR_U32(s); } while(0)
#define PS_SR_F32(s,fv)            do { PS_ENSURE(s,4); (fv) = PS_DR_F32(s); } while(0)
#define PS_SR_F64(s,dv)            do { PS_ENSURE(s,8); (dv) = PS_DR_F64(s); } while(0)
#define PS_SR_BUF(s,buf,len)       do { PS_ENSURE(s, len); PS_DR_BUF(s,buf,len); } while(0)
#define PS_SR_SKIP(s,len)          do { PS_ENSURE(s,len); PS_DR_SKIP(s,len); } while(0)
#define PS_SIZE(s)                 ((s)->size - (s)->pos)


#endif /* pt_h */
