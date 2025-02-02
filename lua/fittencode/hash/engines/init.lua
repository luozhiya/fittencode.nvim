-- lua/hash/engines/init.lua
local M = {}

-- 按性能优先级排序：ffi > openssl > system tools > pure
local engines = {
    require 'hash.engines.ffi',
    require 'hash.engines.openssl',
    require 'hash.engines.md5sum',
    require 'hash.engines.sha1sum',
    require 'hash.engines.sha256sum',
    require 'hash.engines.pure',
}

function M.get_available()
    return vim.tbl_filter(function(e)
        return e.is_available and #e.supported_hashes > 0
    end, engines)
end

function M.supports_hash(engine, algo)
    return vim.tbl_contains(engine.supported_hashes, algo:lower())
end

return M
