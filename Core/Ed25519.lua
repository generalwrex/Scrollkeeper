-- Scrollkeeper: Core/Ed25519.lua
-- Ed25519 signatures (RFC 8032) in plain Lua 5.1, for the board's
-- moderation: the dev team signs with its secret key, and every
-- Scrollkeeper checks with the public key in Network/Board.lua.
-- A public key can check signatures but can't make them.
--
-- Ported from TweetNaCl (public domain): numbers mod 2^255-19 are 16
-- pieces of 16 bits, kept small enough for Lua's doubles to stay exact.
-- SHA-512 works on 64-bit words as two 32-bit halves, with WoW's bit library.
-- Not constant-time (nothing secret is ever handled by players' copies).
-- Number literals that can grow past 2^31 are written as floats (65536.0):
-- the same in WoW, and it keeps the test harness (32-bit integers) exact.
--
--   SK.Ed25519.Verify(signature64, message, publicKey32)  -> true / false
--   SK.Ed25519.Sign(message, seed32)                      -> signature64
--   SK.Ed25519.PublicKey(seed32)                          -> publicKey32
--   (all byte strings; SK.Ed25519.ToBase64 / FromBase64 for messages)

local _, SK = ...
local floor = math.floor
local band, bor, bxor, bnot, rshift, lshift = bit.band, bit.bor, bit.bxor, bit.bnot, bit.rshift, bit.lshift
local TWO32 = 4294967296

------------------------------------------------------------------------
-- SHA-512
------------------------------------------------------------------------

local function U(x) return x % TWO32 end   -- bit ops return signed 32-bit

local K = {
    0x428a2f98, 0xd728ae22, 0x71374491, 0x23ef65cd, 0xb5c0fbcf, 0xec4d3b2f, 0xe9b5dba5, 0x8189dbbc,
    0x3956c25b, 0xf348b538, 0x59f111f1, 0xb605d019, 0x923f82a4, 0xaf194f9b, 0xab1c5ed5, 0xda6d8118,
    0xd807aa98, 0xa3030242, 0x12835b01, 0x45706fbe, 0x243185be, 0x4ee4b28c, 0x550c7dc3, 0xd5ffb4e2,
    0x72be5d74, 0xf27b896f, 0x80deb1fe, 0x3b1696b1, 0x9bdc06a7, 0x25c71235, 0xc19bf174, 0xcf692694,
    0xe49b69c1, 0x9ef14ad2, 0xefbe4786, 0x384f25e3, 0x0fc19dc6, 0x8b8cd5b5, 0x240ca1cc, 0x77ac9c65,
    0x2de92c6f, 0x592b0275, 0x4a7484aa, 0x6ea6e483, 0x5cb0a9dc, 0xbd41fbd4, 0x76f988da, 0x831153b5,
    0x983e5152, 0xee66dfab, 0xa831c66d, 0x2db43210, 0xb00327c8, 0x98fb213f, 0xbf597fc7, 0xbeef0ee4,
    0xc6e00bf3, 0x3da88fc2, 0xd5a79147, 0x930aa725, 0x06ca6351, 0xe003826f, 0x14292967, 0x0a0e6e70,
    0x27b70a85, 0x46d22ffc, 0x2e1b2138, 0x5c26c926, 0x4d2c6dfc, 0x5ac42aed, 0x53380d13, 0x9d95b3df,
    0x650a7354, 0x8baf63de, 0x766a0abb, 0x3c77b2a8, 0x81c2c92e, 0x47edaee6, 0x92722c85, 0x1482353b,
    0xa2bfe8a1, 0x4cf10364, 0xa81a664b, 0xbc423001, 0xc24b8b70, 0xd0f89791, 0xc76c51a3, 0x0654be30,
    0xd192e819, 0xd6ef5218, 0xd6990624, 0x5565a910, 0xf40e3585, 0x5771202a, 0x106aa070, 0x32bbd1b8,
    0x19a4c116, 0xb8d2d0c8, 0x1e376c08, 0x5141ab53, 0x2748774c, 0xdf8eeb99, 0x34b0bcb5, 0xe19b48a8,
    0x391c0cb3, 0xc5c95a63, 0x4ed8aa4a, 0xe3418acb, 0x5b9cca4f, 0x7763e373, 0x682e6ff3, 0xd6b2b8a3,
    0x748f82ee, 0x5defb2fc, 0x78a5636f, 0x43172f60, 0x84c87814, 0xa1f0ab72, 0x8cc70208, 0x1a6439ec,
    0x90befffa, 0x23631e28, 0xa4506ceb, 0xde82bde9, 0xbef9a3f7, 0xb2c67915, 0xc67178f2, 0xe372532b,
    0xca273ece, 0xea26619c, 0xd186b8c7, 0x21c0c207, 0xeada7dd6, 0xcde0eb1e, 0xf57d4f7f, 0xee6ed178,
    0x06f067aa, 0x72176fba, 0x0a637dc5, 0xa2c898a6, 0x113f9804, 0xbef90dae, 0x1b710b35, 0x131c471b,
    0x28db77f5, 0x23047d84, 0x32caab7b, 0x40c72493, 0x3c9ebe0a, 0x15c9bebc, 0x431d67c4, 0x9c100d4c,
    0x4cc5d4be, 0xcb3e42b6, 0x597f299c, 0xfc657e2a, 0x5fcb6fab, 0x3ad6faec, 0x6c44198c, 0x4a475817,
}
for i = 1, #K do K[i] = U(K[i] + 0.0) end

-- 64-bit right rotation of (h, l) by n (0 < n < 64), as two halves.
local function Rotr(h, l, n)
    if n >= 32 then h, l, n = l, h, n - 32 end
    if n == 0 then return h, l end
    return U(bor(rshift(h, n), lshift(l, 32 - n))), U(bor(rshift(l, n), lshift(h, 32 - n)))
end
local function Shr(h, l, n)   -- 0 < n < 32
    return U(rshift(h, n)), U(bor(rshift(l, n), lshift(h, 32 - n)))
end
local function Add(ah, al, bh, bl)
    local l = al + bl
    local carry = floor(l / TWO32)
    return (ah + bh + carry) % TWO32, l % TWO32
end

local function Sha512(bytes)
    local n = #bytes
    local msg = {}
    for i = 1, n do msg[i] = bytes[i] end
    msg[n + 1] = 0x80
    while (#msg % 128) ~= 112 do msg[#msg + 1] = 0 end
    -- Length in bits, as a 128-bit big-endian number.
    local bits = n * 8.0
    for _ = 1, 8 do msg[#msg + 1] = 0 end
    local tail = {}
    for i = 8, 1, -1 do tail[i] = bits % 256; bits = floor(bits / 256) end
    for i = 1, 8 do msg[#msg + 1] = tail[i] end

    local H = { 0x6a09e667, 0xf3bcc908, 0xbb67ae85, 0x84caa73b, 0x3c6ef372, 0xfe94f82b, 0xa54ff53a, 0x5f1d36f1,
                0x510e527f, 0xade682d1, 0x9b05688c, 0x2b3e6c1f, 0x1f83d9ab, 0xfb41bd6b, 0x5be0cd19, 0x137e2179 }
    for i = 1, 16 do H[i] = U(H[i] + 0.0) end
    local W = {}
    for block = 0, #msg / 128 - 1 do
        local base = block * 128
        for t = 0, 15 do
            local o = base + t * 8
            W[t * 2 + 1] = ((msg[o + 1] * 256.0 + msg[o + 2]) * 256.0 + msg[o + 3]) * 256.0 + msg[o + 4]
            W[t * 2 + 2] = ((msg[o + 5] * 256.0 + msg[o + 6]) * 256.0 + msg[o + 7]) * 256.0 + msg[o + 8]
        end
        for t = 16, 79 do
            local h15, l15 = W[(t - 15) * 2 + 1], W[(t - 15) * 2 + 2]
            local ah, al = Rotr(h15, l15, 1)
            local bh, bl = Rotr(h15, l15, 8)
            local ch, cl = Shr(h15, l15, 7)
            local s0h, s0l = U(bxor(ah, bh, ch)), U(bxor(al, bl, cl))
            local h2, l2 = W[(t - 2) * 2 + 1], W[(t - 2) * 2 + 2]
            ah, al = Rotr(h2, l2, 19)
            bh, bl = Rotr(h2, l2, 61)
            ch, cl = Shr(h2, l2, 6)
            local s1h, s1l = U(bxor(ah, bh, ch)), U(bxor(al, bl, cl))
            local rh, rl = Add(W[(t - 16) * 2 + 1], W[(t - 16) * 2 + 2], s0h, s0l)
            rh, rl = Add(rh, rl, W[(t - 7) * 2 + 1], W[(t - 7) * 2 + 2])
            rh, rl = Add(rh, rl, s1h, s1l)
            W[t * 2 + 1], W[t * 2 + 2] = rh, rl
        end
        local ah, al, bh, bl, ch, cl, dh, dl = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        local eh, el, fh, fl, gh, gl, hh, hl = H[9], H[10], H[11], H[12], H[13], H[14], H[15], H[16]
        for t = 0, 79 do
            local xh, xl = Rotr(eh, el, 14)
            local yh, yl = Rotr(eh, el, 18)
            local zh, zl = Rotr(eh, el, 41)
            local S1h, S1l = U(bxor(xh, yh, zh)), U(bxor(xl, yl, zl))
            local chh = U(bxor(band(eh, fh), band(bnot(eh), gh)))
            local chl = U(bxor(band(el, fl), band(bnot(el), gl)))
            local t1h, t1l = Add(hh, hl, S1h, S1l)
            t1h, t1l = Add(t1h, t1l, chh, chl)
            t1h, t1l = Add(t1h, t1l, K[t * 2 + 1], K[t * 2 + 2])
            t1h, t1l = Add(t1h, t1l, W[t * 2 + 1], W[t * 2 + 2])
            xh, xl = Rotr(ah, al, 28)
            yh, yl = Rotr(ah, al, 34)
            zh, zl = Rotr(ah, al, 39)
            local S0h, S0l = U(bxor(xh, yh, zh)), U(bxor(xl, yl, zl))
            local mjh = U(bxor(band(ah, bh), band(ah, ch), band(bh, ch)))
            local mjl = U(bxor(band(al, bl), band(al, cl), band(bl, cl)))
            local t2h, t2l = Add(S0h, S0l, mjh, mjl)
            hh, hl = gh, gl
            gh, gl = fh, fl
            fh, fl = eh, el
            eh, el = Add(dh, dl, t1h, t1l)
            dh, dl = ch, cl
            ch, cl = bh, bl
            bh, bl = ah, al
            ah, al = Add(t1h, t1l, t2h, t2l)
        end
        local add = { ah, al, bh, bl, ch, cl, dh, dl, eh, el, fh, fl, gh, gl, hh, hl }
        for i = 1, 15, 2 do H[i], H[i + 1] = Add(H[i], H[i + 1], add[i], add[i + 1]) end
    end
    local out = {}
    for i = 1, 16 do
        local v = H[i]
        out[#out + 1] = floor(v / 16777216) % 256
        out[#out + 1] = floor(v / 65536) % 256
        out[#out + 1] = floor(v / 256) % 256
        out[#out + 1] = v % 256
    end
    return out
end

------------------------------------------------------------------------
-- Numbers mod 2^255 - 19 (16 pieces of 16 bits)
------------------------------------------------------------------------

local function gf(init)
    local r = {}
    for i = 1, 16 do r[i] = (init and init[i] or 0) + 0.0 end
    return r
end
local gf0, gf1 = gf(), gf({ 1 })
local D = gf({ 0x78a3, 0x1359, 0x4dca, 0x75eb, 0xd8ab, 0x4141, 0x0a4d, 0x0070, 0xe898, 0x7779, 0x4079, 0x8cc7, 0xfe73, 0x2b6f, 0x6cee, 0x5203 })
local D2 = gf({ 0xf159, 0x26b2, 0x9b94, 0xebd6, 0xb156, 0x8283, 0x149a, 0x00e0, 0xd130, 0xeef3, 0x80f2, 0x198e, 0xfce7, 0x56df, 0xd9dc, 0x2406 })
local X = gf({ 0xd51a, 0x8f25, 0x2d60, 0xc956, 0xa7b2, 0x9525, 0xc760, 0x692c, 0xdc5c, 0xfdd6, 0xe231, 0xc0a4, 0x53fe, 0xcd6e, 0x36d3, 0x2169 })
local Y = gf({ 0x6658, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666 })
local I = gf({ 0xa0b0, 0x4a0e, 0x1b27, 0xc4ee, 0xe478, 0xad2f, 0x1806, 0x2f43, 0xd7a7, 0x3dfb, 0x0099, 0x2b4d, 0xdf0b, 0x4fc1, 0x2480, 0x2b83 })

local function Set(r, a) for i = 1, 16 do r[i] = a[i] end end

local function Carry(o)
    for i = 1, 16 do
        o[i] = o[i] + 65536.0
        local c = floor(o[i] / 65536.0) + 0.0
        if i < 16 then o[i + 1] = o[i + 1] + c - 1 else o[1] = o[1] + 38.0 * (c - 1) end
        o[i] = o[i] - c * 65536.0
    end
end

local function Sel(p, q, b)   -- swap p and q when b is 1
    if b == 1 then
        for i = 1, 16 do p[i], q[i] = q[i], p[i] end
    end
end

local function Pack25519(n)
    local t, m = gf(n), gf()
    Carry(t); Carry(t); Carry(t)
    for _ = 1, 2 do
        m[1] = t[1] - 0xffed
        for i = 2, 15 do
            m[i] = t[i] - 0xffff - (floor(m[i - 1] / 65536) % 2)
            m[i - 1] = m[i - 1] % 65536
        end
        m[16] = t[16] - 0x7fff - (floor(m[15] / 65536) % 2)
        local b = floor(m[16] / 65536) % 2
        m[15] = m[15] % 65536
        Sel(t, m, 1 - b)
    end
    local o = {}
    for i = 1, 16 do
        o[2 * i - 1] = t[i] % 256
        o[2 * i] = floor(t[i] / 256) % 256
    end
    return o
end

local function Neq(a, b)
    local x, y = Pack25519(a), Pack25519(b)
    for i = 1, 32 do if x[i] ~= y[i] then return true end end
    return false
end

local function Par(a) return Pack25519(a)[1] % 2 end

local function Unpack25519(n)
    local o = gf()
    for i = 1, 16 do o[i] = n[2 * i - 1] + n[2 * i] * 256.0 end
    o[16] = o[16] % 32768
    return o
end

local function A(o, a, b) for i = 1, 16 do o[i] = a[i] + b[i] end end
local function Z(o, a, b) for i = 1, 16 do o[i] = a[i] - b[i] end end

local t31 = {}
local function M(o, a, b)
    for i = 1, 31 do t31[i] = 0.0 end
    for i = 1, 16 do
        local ai = a[i]
        for j = 1, 16 do t31[i + j - 1] = t31[i + j - 1] + ai * b[j] end
    end
    for i = 1, 15 do t31[i] = t31[i] + 38.0 * t31[i + 16] end
    for i = 1, 16 do o[i] = t31[i] end
    Carry(o); Carry(o)
end
local function S(o, a) M(o, a, a) end

local function Inv(o, i)
    local c = gf(i)
    for a = 253, 0, -1 do
        S(c, c)
        if a ~= 2 and a ~= 4 then M(c, c, i) end
    end
    Set(o, c)
end

local function Pow2523(o, i)
    local c = gf(i)
    for a = 250, 0, -1 do
        S(c, c)
        if a ~= 1 then M(c, c, i) end
    end
    Set(o, c)
end

------------------------------------------------------------------------
-- Points (extended coordinates)
------------------------------------------------------------------------

local function Point() return { gf(), gf(), gf(), gf() } end

local function PointAdd(p, q)
    local a, b, c, d, t, e, f, g, h = gf(), gf(), gf(), gf(), gf(), gf(), gf(), gf(), gf()
    Z(a, p[2], p[1]); Z(t, q[2], q[1]); M(a, a, t)
    A(b, p[1], p[2]); A(t, q[1], q[2]); M(b, b, t)
    M(c, p[4], q[4]); M(c, c, D2)
    M(d, p[3], q[3]); A(d, d, d)
    Z(e, b, a); Z(f, d, c); A(g, d, c); A(h, b, a)
    M(p[1], e, f); M(p[2], h, g); M(p[3], g, f); M(p[4], e, h)
end

local function CSwap(p, q, b) for i = 1, 4 do Sel(p[i], q[i], b) end end

local function PackPoint(p)
    local zi, tx, ty = gf(), gf(), gf()
    Inv(zi, p[3])
    M(tx, p[1], zi)
    M(ty, p[2], zi)
    local r = Pack25519(ty)
    r[32] = r[32] + Par(tx) * 128
    return r
end

local function ScalarMult(p, q, s)
    Set(p[1], gf0); Set(p[2], gf1); Set(p[3], gf1); Set(p[4], gf0)
    for i = 255, 0, -1 do
        local b = floor(s[floor(i / 8) + 1] / 2 ^ (i % 8)) % 2
        CSwap(p, q, b)
        PointAdd(q, p)
        PointAdd(p, p)
        CSwap(p, q, b)
    end
end

local function ScalarBase(p, s)
    local q = Point()
    Set(q[1], X); Set(q[2], Y); Set(q[3], gf1); M(q[4], X, Y)
    ScalarMult(p, q, s)
end

-- The point for a public key, negated (what verifying needs), or nil.
local function UnpackNeg(pk)
    local r = Point()
    local t, chk, num, den, den2, den4, den6 = gf(), gf(), gf(), gf(), gf(), gf(), gf()
    Set(r[3], gf1)
    Set(r[2], Unpack25519(pk))
    S(num, r[2]); M(den, num, D); Z(num, num, r[3]); A(den, r[3], den)
    S(den2, den); S(den4, den2); M(den6, den4, den2); M(t, den6, num); M(t, t, den)
    Pow2523(t, t); M(t, t, num); M(t, t, den); M(t, t, den); M(r[1], t, den)
    S(chk, r[1]); M(chk, chk, den)
    if Neq(chk, num) then M(r[1], r[1], I) end
    S(chk, r[1]); M(chk, chk, den)
    if Neq(chk, num) then return nil end
    if Par(r[1]) == floor(pk[32] / 128) then Z(r[1], gf0, r[1]) end
    M(r[4], r[1], r[2])
    return r
end

------------------------------------------------------------------------
-- Numbers mod L (the group order)
------------------------------------------------------------------------

local L = { 0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10 }

-- x: 64 numbers (1-based), changed; returns 32 bytes.
local function ModL(x)
    for i = 64, 33, -1 do
        local carry = 0
        local j = i - 32
        while j < i - 12 do
            x[j] = x[j] + carry - 16.0 * x[i] * L[j - (i - 32) + 1]
            carry = floor((x[j] + 128) / 256.0) + 0.0
            x[j] = x[j] - carry * 256.0
            j = j + 1
        end
        x[j] = x[j] + carry
        x[i] = 0
    end
    local carry = 0
    for j = 1, 32 do
        x[j] = x[j] + carry - floor(x[32] / 16) * L[j]
        carry = floor(x[j] / 256)
        x[j] = x[j] % 256
    end
    for j = 1, 32 do x[j] = x[j] - carry * L[j] end
    local r = {}
    for i = 1, 32 do
        x[i + 1] = x[i + 1] + floor(x[i] / 256)
        r[i] = x[i] % 256
    end
    return r
end

local function Reduce(h64)
    local x = {}
    for i = 1, 64 do x[i] = h64[i] + 0.0 end
    return ModL(x)
end

------------------------------------------------------------------------
-- Bytes and strings
------------------------------------------------------------------------

local function Bytes(s)
    local t = {}
    for i = 1, #s do t[i] = s:byte(i) end
    return t
end
local function Str(t)
    local parts = {}
    for i = 1, #t do parts[i] = string.char(t[i]) end
    return table.concat(parts)
end
local function Join(...)
    local out = {}
    for _, t in ipairs({ ... }) do for i = 1, #t do out[#out + 1] = t[i] end end
    return out
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, 64 do B64_INDEX[B64:sub(i, i)] = i - 1 end

local function ToBase64(s)
    local out, n = {}, #s
    for i = 1, n, 3 do
        local a, b, c = s:byte(i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local chars = 2 + (b and 1 or 0) + (c and 1 or 0)
        for k = 1, chars do
            local idx = floor(v / 2 ^ (18 - 6 * (k - 1))) % 64
            out[#out + 1] = B64:sub(idx + 1, idx + 1)
        end
    end
    return table.concat(out)
end

local function FromBase64(s)
    if type(s) ~= "string" then return nil end
    local out, v, bits = {}, 0, 0
    for i = 1, #s do
        local idx = B64_INDEX[s:sub(i, i)]
        if not idx then return nil end
        v = v * 64 + idx
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            out[#out + 1] = string.char(floor(v / 2 ^ bits) % 256)
            v = v % 2 ^ bits
        end
    end
    return table.concat(out)
end

------------------------------------------------------------------------
-- Sign and verify
------------------------------------------------------------------------

local function Clamp(d)
    d[1] = d[1] - d[1] % 8
    d[32] = d[32] % 128
    if d[32] < 64 then d[32] = d[32] + 64 end
end

local function PublicKeyBytes(seed)
    local d = Sha512(seed)
    Clamp(d)
    local p = Point()
    ScalarBase(p, d)
    return PackPoint(p), d
end

local E = {}

function E.PublicKey(seed)
    if type(seed) ~= "string" or #seed ~= 32 then return nil end
    return Str((PublicKeyBytes(Bytes(seed))))
end

function E.Sign(message, seed)
    if type(seed) ~= "string" or #seed ~= 32 then return nil end
    local pk, d = PublicKeyBytes(Bytes(seed))
    local m = Bytes(message)
    local prefix = {}
    for i = 33, 64 do prefix[#prefix + 1] = d[i] end
    local r = Reduce(Sha512(Join(prefix, m)))
    local p = Point()
    ScalarBase(p, r)
    local R = PackPoint(p)
    local h = Reduce(Sha512(Join(R, pk, m)))
    local x = {}
    for i = 1, 64 do x[i] = 0.0 end
    for i = 1, 32 do x[i] = r[i] + 0.0 end
    for i = 1, 32 do
        for j = 1, 32 do x[i + j - 1] = x[i + j - 1] + h[i] * (d[j] + 0.0) end
    end
    local s = ModL(x)
    return Str(R) .. Str(s)
end

function E.Verify(signature, message, publicKey)
    if type(signature) ~= "string" or #signature ~= 64 then return false end
    if type(publicKey) ~= "string" or #publicKey ~= 32 or type(message) ~= "string" then return false end
    local pk, sig = Bytes(publicKey), Bytes(signature)
    -- S has to be below 2^253 (the top 3 bits clear), like TweetNaCl.
    if sig[64] >= 32 then return false end
    local q = UnpackNeg(pk)
    if not q then return false end
    local R, s = {}, {}
    for i = 1, 32 do R[i] = sig[i]; s[i] = sig[i + 32] end
    local h = Reduce(Sha512(Join(R, pk, Bytes(message))))
    local p = Point()
    ScalarMult(p, q, h)
    local sb = Point()
    ScalarBase(sb, s)
    PointAdd(p, sb)
    local t = PackPoint(p)
    for i = 1, 32 do if t[i] ~= R[i] then return false end end
    return true
end

function E.Sha512(s) return Str(Sha512(Bytes(s))) end
E.ToBase64, E.FromBase64 = ToBase64, FromBase64

SK.Ed25519 = E
