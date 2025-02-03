--[[
local fz = require('loom')

-- 压缩示例
fz.compress("test data", "gzip")
   :forward(function(compressed)
       print("Compressed:", compressed)
   end, function(err)
       print("Error:", err)
   end)

-- 解压示例
fz.decompress(compressed_data, "gzip")
   :forward(function(decompressed)
       print("Decompressed:", decompressed)
   end)
--]]

local Promise = require('fittencode.concurrency.promise')

local M = {}
local engines = {}

local function load_engines()
    local engine_names = { 'gzip', 'native', 'zlib' }
    for _, name in ipairs(engine_names) do
        local ok, engine = pcall(require, 'fittencode.loom.engines.' .. name)
        if ok and engine._setup then
            engine._setup()
            table.insert(engines, engine)
        end
    end
end

function M.setup()
    load_engines()
end

local function find_engines(algorithm, operation)
    local candidates = {}
    for _, engine in ipairs(engines) do
        if engine.supported[operation] and vim.tbl_contains(engine.supported[operation], algorithm) then
            table.insert(candidates, engine)
        end
    end
    return candidates
end

function M.compress(input, algorithm, options)
    options = options or {}
    local candidates = find_engines(algorithm, 'compress')

    local promise = Promise.reject('No engines available')
    for _, engine in ipairs(candidates) do
        promise = promise:catch(function()
            return engine.compress(input, algorithm, options)
        end)
    end
    return promise
end

function M.decompress(input, algorithm, options)
    options = options or {}
    local candidates = find_engines(algorithm, 'decompress')

    local promise = Promise.reject('No engines available')
    for _, engine in ipairs(candidates) do
        promise = promise:catch(function()
            return engine.decompress(input, algorithm, options)
        end)
    end
    return promise
end

return M
