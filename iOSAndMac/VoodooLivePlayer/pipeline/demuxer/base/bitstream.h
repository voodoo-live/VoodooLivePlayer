//
//  bitstream.h
//  QLive
//
//  Created by voodoo on 2019/12/12.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

#ifndef bitstream_h
#define bitstream_h

#include <stdint.h>
#include <memory.h>
typedef struct bitstream_s {
    uint8_t* data;
    uint32_t len;
    uint32_t pos;           /*  0~len */
    uint32_t bit_pos;       /*  0~7 */
} bitstream_t;

/*
 interfaces
 */

#define BS_INIT(bs, bdata, blen) (bs)->data = (uint8_t*)(bdata), (bs)->len = (blen), (bs)->pos = (bs)->bit_pos = 0

static inline uint8_t BS_READ_BIT(bitstream_t *bs) {
    if(bs->pos >= bs->len) {
        return 0;
    }
    uint8_t ret = ((bs->data[bs->pos] & (1<<(7-bs->bit_pos)))>>(7-bs->bit_pos));
    ++bs->bit_pos;
    if(bs->bit_pos >= 8) {
        bs->bit_pos = 0;
        ++bs->pos;
    }
    return ret;
}

static inline uint8_t BS_READ_BYTE(bitstream_t *bs) {
    if(bs->pos >= bs->len) {
        return 0;
    }
    uint32_t len = 8;
    uint32_t left_bit_count = (bs->len - bs->pos - 1) * 8 + 8 - bs->bit_pos;
    if(left_bit_count < len) {
        len = left_bit_count;
    }
    
    uint8_t ret;
    uint32_t head_bits_count = 8-bs->bit_pos;
    
    
    if(len <= head_bits_count) {
        uint8_t mask = (uint8_t)((1U<<len)-1) << (8-len);
        uint8_t move = (8-len);
        ret = ((bs->data[bs->pos] << move) & mask);
        bs->bit_pos += len;
        if(bs->bit_pos >= 8) {
            ++bs->pos;
            bs->bit_pos = 0;
        }
    } else {
        uint8_t mask1 = (uint8_t)((1U<<head_bits_count)-1) << (8-head_bits_count);
        uint8_t mask2 = (uint8_t)((1U<<(len-head_bits_count))-1) << (8-len);
        
        uint8_t move1 = (8-head_bits_count);
        uint8_t move2 = head_bits_count;
        
        ret = ((bs->data[bs->pos] << move1) & mask1);
        ++bs->pos;
        ret |= ((bs->data[bs->pos] >> move2) & mask2);
        bs->bit_pos = len-head_bits_count;
    }
    return ret;
}

#define _BS_READ_SAMPLE_BIT(sample, from_pos, to_pos, len)          (uint8_t)((sample))

//#define _BYTE_BITS_COPY(from_byte, from_pos, to_pos, copy_len)

/*
 from_pos 0~7
 to_pos 0~7
 copy_len 1~8
 copy_len <= (8-to_pos)
 copy_len <= (8-from_pos)
 */
static inline uint8_t _BYTE_BITS_COPY(uint8_t from_byte, uint8_t from_pos, uint8_t to_pos, uint8_t copy_len) {
    uint8_t mask = (uint8_t)((1U<<copy_len)-1);
    from_byte = (from_byte >> (8-from_pos-copy_len)) & mask;
    return (from_byte << (8-to_pos-copy_len));
}

#define __BYTE_BITS_COPY(fb,fpos,tpos,len)          ((uint8_t)((((fb) >> (8-(fpos)-(len)))&((uint8_t)((1U<<(len))-1))) << (8-(tpos)-(len))))

static inline int32_t BS_READ(bitstream_t *bs, uint8_t *buf, uint32_t len) {
    if(bs->pos >= bs->len) {
        return 0;
    }
    uint32_t left_bit_count = (bs->len - bs->pos - 1) * 8 + 8 - bs->bit_pos;
    if(left_bit_count < len) {
        len = left_bit_count;
    }
    /*
     first byte left bits
     */
    uint32_t head_bits_count = (8-bs->bit_pos) % 8;
    uint32_t tail_bits_count, read_byte_count;
    uint8_t sample = bs->data[bs->pos];
    /*
     首部拷贝位数是0，可以直接字节对齐拷贝
     */
    if(head_bits_count == 0) {
        /*
         首字节不需要做位拷贝
         */
        tail_bits_count = len % 8;
        read_byte_count = len / 8;
        /*
         拷贝中间字节
         */
        if(read_byte_count > 0) {
            memcpy(buf, bs->data, read_byte_count);
            bs->pos += read_byte_count;
            buf += read_byte_count;
            sample = bs->data[bs->pos];
        }
        /*
         拷贝尾余位
         */
        if(tail_bits_count > 0) {
            *buf = __BYTE_BITS_COPY(sample, 0, 0, tail_bits_count);
            bs->bit_pos = tail_bits_count;
        }
    } else if(len <= head_bits_count) {
        *buf = __BYTE_BITS_COPY(sample, bs->bit_pos, 0, len);
        bs->bit_pos += len;
        if(bs->bit_pos >= 8) {
            ++bs->pos;
            bs->bit_pos = 0;
        }
    } else {
        tail_bits_count = (len-head_bits_count) % 8;
        read_byte_count = len / 8;
        
        /*
         对于每个buf的字节
         拷贝head_bits_count和下一个字节的8-head_bits_count的位
         拷贝到0位置和head_bits_count位置
         */
        
        uint8_t mask1 = (uint8_t)((1U<<head_bits_count)-1) << (8-head_bits_count);
        uint8_t mask2 = (uint8_t)((1U<<(8-head_bits_count))-1);
        
        uint8_t move1 = (8-head_bits_count);
        uint8_t move2 = head_bits_count;
        
        for(uint32_t i = 0;i < read_byte_count;++i) {
            buf[i] = (bs->data[bs->pos] << move1) & mask1;
            ++bs->pos;
            buf[i] |= (bs->data[bs->pos] >> move2) & mask2;
        }
        
        buf += read_byte_count;
        
        if(tail_bits_count > 0) {
            if(tail_bits_count <= head_bits_count) {
                *buf = __BYTE_BITS_COPY(bs->data[bs->pos], bs->bit_pos, 0, tail_bits_count);
                bs->bit_pos += tail_bits_count;
                if(bs->bit_pos >= 8) {
                    ++bs->pos;
                    bs->bit_pos = 0;
                }
            } else {
                *buf = (bs->data[bs->pos] << move1) & mask1;
                ++bs->pos;
                bs->bit_pos = tail_bits_count - head_bits_count;
                *buf |= __BYTE_BITS_COPY(bs->data[bs->pos], 0, head_bits_count, bs->bit_pos);
            }
        }
        
    }
    
    return (int32_t)len;
}

static inline void BS_SKIP(bitstream_t *bs, uint32_t len) {
    bs->bit_pos += len;
    bs->pos += bs->bit_pos / 8;
    bs->bit_pos %= 8;
    if(bs->pos > bs->len) {
        bs->pos = bs->len;
        bs->bit_pos = 0;
    }
}

//#define BS_READ8_1(bs)          (bs)->pos >= (bs)->len ? 0 : (((bs)->data[(bs)->pos] & (1<<(7-(bs)->bit_pos)))>>(7-(bs)->bit_pos))
//#define BS_READ8(bs, len)
#define BS_READ16(bs,len)
#define BS_READ32(bs,len)



#endif /* bitstream_h */
