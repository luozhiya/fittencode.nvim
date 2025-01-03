#include <stdint.h>
#include <string.h>
#include <stdio.h>

#include "md5.h"

// MD5 context structure
typedef struct {
    uint32_t state[4];
    uint32_t count[2];
    uint8_t buffer[64];
} MD5_CTX;

// Constants for MD5Transform routine
#define S11 7
#define S12 12
#define S13 17
#define S14 22
#define S21 5
#define S22 9
#define S23 14
#define S24 20
#define S31 4
#define S32 11
#define S33 16
#define S34 23
#define S41 6
#define S42 10
#define S43 15
#define S44 21

// F, G, H, and I are basic MD5 functions
#define F(x, y, z) (((x) & (y)) | ((~x) & (z)))
#define G(x, y, z) (((x) & (z)) | ((y) & (~z)))
#define H(x, y, z) ((x) ^ (y) ^ (z))
#define I(x, y, z) ((y) ^ ((x) | (~z)))

// Rotate left operation
#define ROTATE_LEFT(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

// FF, GG, HH, and II transformations
#define FF(a, b, c, d, x, s, ac) { \
    (a) += F((b), (c), (d)) + (x) + (uint32_t)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}

#define GG(a, b, c, d, x, s, ac) { \
    (a) += G((b), (c), (d)) + (x) + (uint32_t)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}

#define HH(a, b, c, d, x, s, ac) { \
    (a) += H((b), (c), (d)) + (x) + (uint32_t)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}

#define II(a, b, c, d, x, s, ac) { \
    (a) += I((b), (c), (d)) + (x) + (uint32_t)(ac); \
    (a) = ROTATE_LEFT((a), (s)); \
    (a) += (b); \
}

// MD5 padding
static const uint8_t PADDING[64] = {
    0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

// declare static function
static void MD5_Transform(uint32_t state[4], const uint8_t block[64]);
static void Decode(uint32_t *output, const uint8_t *input, size_t len);
static void Encode(uint8_t *output, const uint32_t *input, size_t len);

// MD5 initialization
void MD5_Init(MD5_CTX *context) {
    context->count[0] = context->count[1] = 0;
    context->state[0] = 0x67452301;
    context->state[1] = 0xEFCDAB89;
    context->state[2] = 0x98BADCFE;
    context->state[3] = 0x10325476;
}

// MD5 block update operation
void MD5_Update(MD5_CTX *context, const uint8_t *input, size_t inputLen) {
    size_t i, index, partLen;

    index = (size_t)((context->count[0] >> 3) & 0x3F);

    if ((context->count[0] += ((uint32_t)inputLen << 3)) < ((uint32_t)inputLen << 3))
        context->count[1]++;
    context->count[1] += ((uint32_t)inputLen >> 29);

    partLen = 64 - index;

    if (inputLen >= partLen) {
        memcpy(&context->buffer[index], input, partLen);
        MD5_Transform(context->state, context->buffer);

        for (i = partLen; i + 63 < inputLen; i += 64)
            MD5_Transform(context->state, &input[i]);

        index = 0;
    } else {
        i = 0;
    }

    memcpy(&context->buffer[index], &input[i], inputLen - i);
}

// MD5 finalization
void MD5_Final(uint8_t digest[16], MD5_CTX *context) {
    uint8_t bits[8];
    size_t index, padLen;

    Encode(bits, context->count, 8);

    index = (size_t)((context->count[0] >> 3) & 0x3F);
    padLen = (index < 56) ? (56 - index) : (120 - index);
    MD5_Update(context, PADDING, padLen);

    MD5_Update(context, bits, 8);

    Encode(digest, context->state, 16);

    memset(context, 0, sizeof(*context));
}

// MD5 basic transformation
static void MD5_Transform(uint32_t state[4], const uint8_t block[64]) {
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3], x[16];

    Decode(x, block, 64);

    FF(a, b, c, d, x[0], S11, 0xD76AA478);
    FF(d, a, b, c, x[1], S12, 0xE8C7B756);
    FF(c, d, a, b, x[2], S13, 0x242070DB);
    FF(b, c, d, a, x[3], S14, 0xC1BDCEEE);
    FF(a, b, c, d, x[4], S11, 0xF57C0FAF);
    FF(d, a, b, c, x[5], S12, 0x4787C62A);
    FF(c, d, a, b, x[6], S13, 0xA8304613);
    FF(b, c, d, a, x[7], S14, 0xFD469501);
    FF(a, b, c, d, x[8], S11, 0x698098D8);
    FF(d, a, b, c, x[9], S12, 0x8B44F7AF);
    FF(c, d, a, b, x[10], S13, 0xFFFF5BB1);
    FF(b, c, d, a, x[11], S14, 0x895CD7BE);
    FF(a, b, c, d, x[12], S11, 0x6B901122);
    FF(d, a, b, c, x[13], S12, 0xFD987193);
    FF(c, d, a, b, x[14], S13, 0xA679438E);
    FF(b, c, d, a, x[15], S14, 0x49B40821);

    GG(a, b, c, d, x[1], S21, 0xF61E2562);
    GG(d, a, b, c, x[6], S22, 0xC040B340);
    GG(c, d, a, b, x[11], S23, 0x265E5A51);
    GG(b, c, d, a, x[0], S24, 0xE9B6C7AA);
    GG(a, b, c, d, x[5], S21, 0xD62F105D);
    GG(d, a, b, c, x[10], S22, 0x2441453);
    GG(c, d, a, b, x[15], S23, 0xD8A1E681);
    GG(b, c, d, a, x[4], S24, 0xE7D3FBC8);
    GG(a, b, c, d, x[9], S21, 0x21E1CDE6);
    GG(d, a, b, c, x[14], S22, 0xC33707D6);
    GG(c, d, a, b, x[3], S23, 0xF4D50D87);
    GG(b, c, d, a, x[8], S24, 0x455A14ED);
    GG(a, b, c, d, x[13], S21, 0xA9E3E905);
    GG(d, a, b, c, x[2], S22, 0xFCEFA3F8);
    GG(c, d, a, b, x[7], S23, 0x676F02D9);
    GG(b, c, d, a, x[12], S24, 0x8D2A4C8A);

    HH(a, b, c, d, x[5], S31, 0xFFFA3942);
    HH(d, a, b, c, x[8], S32, 0x8771F681);
    HH(c, d, a, b, x[11], S33, 0x6D9D6122);
    HH(b, c, d, a, x[14], S34, 0xFDE5380C);
    HH(a, b, c, d, x[1], S31, 0xA4BEEA44);
    HH(d, a, b, c, x[4], S32, 0x4BDECFA9);
    HH(c, d, a, b, x[7], S33, 0xF6BB4B60);
    HH(b, c, d, a, x[10], S34, 0xBEBFBC70);
    HH(a, b, c, d, x[13], S31, 0x289B7EC6);
    HH(d, a, b, c, x[0], S32, 0xEAA127FA);
    HH(c, d, a, b, x[3], S33, 0xD4EF3085);
    HH(b, c, d, a, x[6], S34, 0x4881D05);
    HH(a, b, c, d, x[9], S31, 0xD9D4D039);
    HH(d, a, b, c, x[12], S32, 0xE6DB99E5);
    HH(c, d, a, b, x[15], S33, 0x1FA27CF8);
    HH(b, c, d, a, x[2], S34, 0xC4AC5665);

    II(a, b, c, d, x[0], S41, 0xF4292244);
    II(d, a, b, c, x[7], S42, 0x432AFF97);
    II(c, d, a, b, x[14], S43, 0xAB9423A7);
    II(b, c, d, a, x[5], S44, 0xFC93A039);
    II(a, b, c, d, x[12], S41, 0x655B59C3);
    II(d, a, b, c, x[3], S42, 0x8F0CCC92);
    II(c, d, a, b, x[10], S43, 0xFFEFF47D);
    II(b, c, d, a, x[1], S44, 0x85845DD1);
    II(a, b, c, d, x[8], S41, 0x6FA87E4F);
    II(d, a, b, c, x[15], S42, 0xFE2CE6E0);
    II(c, d, a, b, x[6], S43, 0xA3014314);
    II(b, c, d, a, x[13], S44, 0x4E0811A1);
    II(a, b, c, d, x[4], S41, 0xF7537E82);
    II(d, a, b, c, x[11], S42, 0xBD3AF235);
    II(c, d, a, b, x[2], S43, 0x2AD7D2BB);
    II(b, c, d, a, x[9], S44, 0xEB86D391);

    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;

    memset(x, 0, sizeof(x));
}

// Encode input into output
static void Encode(uint8_t *output, const uint32_t *input, size_t len) {
    size_t i, j;

    for (i = 0, j = 0; j < len; i++, j += 4) {
        output[j] = (uint8_t)(input[i] & 0xFF);
        output[j + 1] = (uint8_t)((input[i] >> 8) & 0xFF);
        output[j + 2] = (uint8_t)((input[i] >> 16) & 0xFF);
        output[j + 3] = (uint8_t)((input[i] >> 24) & 0xFF);
    }
}

// Decode input into output
static void Decode(uint32_t *output, const uint8_t *input, size_t len) {
    size_t i, j;

    for (i = 0, j = 0; j < len; i++, j += 4)
        output[i] = ((uint32_t)input[j]) | (((uint32_t)input[j + 1]) << 8) |
                    (((uint32_t)input[j + 2]) << 16) | (((uint32_t)input[j + 3]) << 24);
}

// MD5 hash function
void md5_hash(const char *input, uint8_t output[16]) {
    MD5_CTX context;
    MD5_Init(&context);
    MD5_Update(&context, (const uint8_t *)input, strlen(input));
    MD5_Final(output, &context);
}
