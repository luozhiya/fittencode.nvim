-- lua/hash/md5.lua
local engines = require 'hash.engines'

local function md5(input, is_file)
    for _, engine in ipairs(engines.get_available()) do
        if engines.supports_hash(engine, 'md5') then
            return engine.hash('md5', input, is_file)
        end
    end
    return vim.promise.reject('No available engine for MD5')
end

return md5
