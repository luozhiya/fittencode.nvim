local ffi = require('ffi')
local Promise = require('fittencode.concurrency.promise')

ffi.cdef [[
typedef struct evp_md_ctx_st EVP_MD_CTX;
typedef struct engine_st ENGINE;
typedef struct evp_md_st EVP_MD;

EVP_MD_CTX *EVP_MD_CTX_new(void);
void EVP_MD_CTX_free(EVP_MD_CTX *ctx);
const EVP_MD *EVP_get_digestbyname(const char *name);
int EVP_DigestInit_ex(EVP_MD_CTX *ctx, const EVP_MD *type, ENGINE *impl);
int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *d, size_t cnt);
int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md, unsigned int *s);
]]

local libcrypto = ffi.load('crypto')

local algorithm_map = {
    ['blake2b512'] = 'blake2b512',
    ['blake2s256'] = 'blake2s256',
    ['md4']        = 'md4',
    ['md5']        = 'md5',
    ['mdc2']       = 'mdc2',
    ['rmd160']     = 'rmd160',
    ['sha1']       = 'sha1',
    ['sha224']     = 'sha224',
    ['sha256']     = 'sha256',
    ['sha3-224']   = 'sha3-224',
    ['sha3-256']   = 'sha3-256',
    ['sha3-384']   = 'sha3-384',
    ['sha3-512']   = 'sha3-512',
    ['sha384']     = 'sha384',
    ['sha512']     = 'sha512',
    ['sha512-224'] = 'sha512-224',
    ['sha512-256'] = 'sha512-256',
    ['shake128']   = 'shake128',
    ['shake256']   = 'shake256',
    ['sm3']        = 'sm3'
}

local M = {
    name = 'libcrypto',
    algorithms = vim.tbl_keys(algorithm_map)
}

function M.is_available()
    return libcrypto ~= nil
end

local function hex_encode(bin)
    return bin:gsub('.', function(c) return string.format('%02x', c:byte()) end)
end

function M.hash(algorithm, data, options)
    return Promise.new(function(resolve, reject, async)
        local algo_name = algorithm_map[algorithm]
        if not algo_name then return reject('Unsupported algorithm') end

        local md = libcrypto.EVP_get_digestbyname(algo_name)
        if md == nil then return reject('Algorithm not found') end

        local ctx = libcrypto.EVP_MD_CTX_new()
        if ctx == nil then return reject('Failed to create context') end

        if libcrypto.EVP_DigestInit_ex(ctx, md, nil) ~= 1 then
            libcrypto.EVP_MD_CTX_free(ctx)
            return reject('Init failed')
        end

        local is_file = options.input_type == 'file' or
            (type(data) == 'string' and vim.fn.filereadable(data) == 1)

        if is_file then
            local fd = vim.loop.fs_open(data, 'r', 438)
            if not fd then return reject('File open failed') end

            local chunk_size = 4096
            local function read_next()
                vim.loop.fs_read(fd, chunk_size, -1, function(err, chunk)
                    if err then return reject(err) end
                    if #chunk > 0 then
                        libcrypto.EVP_DigestUpdate(ctx, chunk, #chunk)
                        read_next()
                    else
                        vim.loop.fs_close(fd, function(close_err)
                            if close_err then return reject(close_err) end
                            local digest = ffi.new('unsigned char[?]', 64)
                            local len = ffi.new('unsigned int[1]')
                            libcrypto.EVP_DigestFinal_ex(ctx, digest, len)
                            libcrypto.EVP_MD_CTX_free(ctx)
                            resolve(hex_encode(ffi.string(digest, len[0])))
                        end)
                    end
                end)
            end
            read_next()
        else
            libcrypto.EVP_DigestUpdate(ctx, data, #data)
            local digest = ffi.new('unsigned char[?]', 64)
            local len = ffi.new('unsigned int[1]')
            libcrypto.EVP_DigestFinal_ex(ctx, digest, len)
            libcrypto.EVP_MD_CTX_free(ctx)
            resolve(hex_encode(ffi.string(digest, len[0])))
        end
    end, true) -- 异步模式
end

return M
