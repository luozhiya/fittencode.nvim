-- lua/hash/engines/ffi.lua
local M = {
    name = 'ffi',
    supported_hashes = {},
    is_available = false,
}

local ffi
local libcrypto

local ok, _ = pcall(function()
    ffi = require('ffi')
    ffi.cdef [[
    typedef struct EVP_MD_CTX EVP_MD_CTX;
    EVP_MD_CTX *EVP_MD_CTX_new(void);
    void EVP_MD_CTX_free(EVP_MD_CTX *ctx);
    const void *EVP_md5(void);
    const void *EVP_sha1(void);
    const void *EVP_sha256(void);
    int EVP_DigestInit_ex(EVP_MD_CTX *ctx, const void *type, void *impl);
    int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *d, size_t cnt);
    int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md, unsigned int *s);
    ]]
    libcrypto = ffi.load('crypto')
end)

if ok and libcrypto then
    M.is_available = true
    M.supported_hashes = { 'md5', 'sha1', 'sha256' }
end

function M.hash(algo, input, is_file)
    return vim.promise.new(function(resolve, reject)
        local algo_map = {
            md5 = libcrypto.EVP_md5(),
            sha1 = libcrypto.EVP_sha1(),
            sha256 = libcrypto.EVP_sha256(),
        }
        if not algo_map[algo] then return reject('Unsupported algorithm') end

        local ctx = libcrypto.EVP_MD_CTX_new()
        if ctx == nil then return reject('Failed to create context') end

        if libcrypto.EVP_DigestInit_ex(ctx, algo_map[algo], nil) ~= 1 then
            libcrypto.EVP_MD_CTX_free(ctx)
            return reject('Init failed')
        end

        if is_file then
            local fd = vim.loop.fs_open(input, 'r', 438)
            if not fd then return reject('File open failed') end
            -- 异步文件处理...
        else
            libcrypto.EVP_DigestUpdate(ctx, input, #input)
            local digest = ffi.new('unsigned char[64]')
            local digest_len = ffi.new('unsigned int[1]')
            if libcrypto.EVP_DigestFinal_ex(ctx, digest, digest_len) ~= 1 then
                libcrypto.EVP_MD_CTX_free(ctx)
                return reject('Final failed')
            end
            local result = ffi.string(digest, digest_len[0])
            libcrypto.EVP_MD_CTX_free(ctx)
            resolve(require('hash.utils').hex(result))
        end
    end)
end

return M
