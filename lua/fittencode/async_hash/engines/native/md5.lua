local bit = require('bit')
local band, bor, bxor, bnot, lshift, rshift, rol =
    bit.band, bit.bor, bit.bxor, bit.bnot, bit.lshift, bit.rshift, bit.rol

local function bytes_to_w32(b1, b2, b3, b4)
    return bor(lshift(b4, 24), lshift(b3, 16), lshift(b2, 8), b1)
end

local function w32_to_bytes(w)
    return
        band(w, 0xff),
        band(rshift(w, 8), 0xff),
        band(rshift(w, 16), 0xff),
        rshift(w, 24)
end

local function md5_padding(msg_len)
    local pad_len = 64 - ((msg_len + 9) % 64)
    return string.char(0x80) .. string.rep('\0', pad_len - 1) .. string.pack('<I8', msg_len * 8)
end

local function F(x, y, z) return bxor(z, band(x, bxor(y, z))) end
local function G(x, y, z) return bxor(y, band(z, bxor(x, y))) end
local function H(x, y, z) return bxor(x, bxor(y, z)) end
local function I(x, y, z) return bxor(y, bor(x, bnot(z))) end

local function round(a, b, c, d, k, s, i, f)
    local temp = rol((a + f(b, c, d) + k + i) % 0x100000000, s)
    return (b + temp) % 0x100000000
end

local function md5_process_block(block, a0, b0, c0, d0)
    local w = {}
    for i = 0, 15 do
        local j = i * 4 + 1
        w[i] = bytes_to_w32(block:byte(j, j + 3))
    end

    local a, b, c, d = a0, b0, c0, d0

    -- Round 1
    for i = 0, 15 do
        a = round(a, b, c, d, w[i], 7, 0xd76aa478, F)
        d = round(d, a, b, c, w[(i + 1) % 16], 12, 0xe8c7b756, F)
        c = round(c, d, a, b, w[(i + 2) % 16], 17, 0x242070db, F)
        b = round(b, c, d, a, w[(i + 3) % 16], 22, 0xc1bdceee, F)
    end

    -- Round 2
    for i = 0, 15 do
        local idx = (5 * i + 1) % 16
        a = round(a, b, c, d, w[idx], 5, 0xf57c0faf, G)
        d = round(d, a, b, c, w[(5 * (i + 1) + 1) % 16], 9, 0x4787c62a, G)
        c = round(c, d, a, b, w[(5 * (i + 2) + 1) % 16], 14, 0xa8304613, G)
        b = round(b, c, d, a, w[(5 * (i + 3) + 1) % 16], 20, 0xfd469501, G)
    end

    -- Round 3
    for i = 0, 15 do
        local idx = (3 * i + 5) % 16
        a = round(a, b, c, d, w[idx], 4, 0x698098d8, H)
        d = round(d, a, b, c, w[(3 * (i + 1) + 5) % 16], 11, 0x8b44f7af, H)
        c = round(c, d, a, b, w[(3 * (i + 2) + 5) % 16], 16, 0xffff5bb1, H)
        b = round(b, c, d, a, w[(3 * (i + 3) + 5) % 16], 23, 0x895cd7be, H)
    end

    -- Round 4
    for i = 0, 15 do
        local idx = (7 * i) % 16
        a = round(a, b, c, d, w[idx], 6, 0x6b901122, I)
        d = round(d, a, b, c, w[(7 * (i + 1)) % 16], 10, 0xfd987193, I)
        c = round(c, d, a, b, w[(7 * (i + 2)) % 16], 15, 0xa679438e, I)
        b = round(b, c, d, a, w[(7 * (i + 3)) % 16], 21, 0x49b40821, I)
    end

    return
        (a0 + a) % 0x100000000,
        (b0 + b) % 0x100000000,
        (c0 + c) % 0x100000000,
        (d0 + d) % 0x100000000
end

local M = {}

function M.hash(data)
    local a = 0x67452301
    local b = 0xEFCDAB89
    local c = 0x98BADCFE
    local d = 0x10325476

    -- 处理数据块
    data = data .. md5_padding(#data)
    for pos = 1, #data, 64 do
        local chunk = data:sub(pos, pos + 63)
        a, b, c, d = md5_process_block(chunk, a, b, c, d)
    end

    -- 转换为小端字节序
    local b1, b2, b3, b4 = w32_to_bytes(a)
    local h1 = string.format('%02x%02x%02x%02x', b1, b2, b3, b4)
    b1, b2, b3, b4 = w32_to_bytes(b)
    local h2 = string.format('%02x%02x%02x%02x', b1, b2, b3, b4)
    b1, b2, b3, b4 = w32_to_bytes(c)
    local h3 = string.format('%02x%02x%02x%02x', b1, b2, b3, b4)
    b1, b2, b3, b4 = w32_to_bytes(d)
    local h4 = string.format('%02x%02x%02x%02x', b1, b2, b3, b4)

    return h1 .. h2 .. h3 .. h4
end

return M
