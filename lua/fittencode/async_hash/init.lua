--[[
local AsyncHash = require('fittencode.async_hash')

-- 计算字符串MD5
AsyncHash.md5("hello")
    :forward(function(hash) print("MD5:", hash) end)

-- 计算文件SHA256
AsyncHash.sha256("/path/to/file", {input_type = 'file'})
    :forward(function(hash) print("SHA256:", hash) end)
--]]

local Promise = require('fittencode.concurrency.promise')

-- 引擎列表
local engine_names = {
    'openssl',
    'md5sum',
    'sha1sum',
    'sha256sum',
    'libcrypto',
    'native',
}

-- 引擎模块
local modoules = {}

-- 根据 Hash 算法分类引擎
local algorithm_engines = {}

local M = {}

function M.setup()
    -- 加载引擎模块
    for _, name in ipairs(engine_names) do
        local ok, mod = pcall(require, 'fittencode.async_hash.engines.' .. name)
        if ok then
            table.insert(modoules, mod)
        end
    end
    -- 初始化可用引擎
    local available_engines = {}
    for _, engine in ipairs(modoules) do
        if engine.is_available() then
            table.insert(available_engines, engine)
            for _, algo in ipairs(engine.algorithms) do
                if not algorithm_engines[algo] then
                    algorithm_engines[algo] = {}
                end
                table.insert(algorithm_engines[algo], engine)
            end
        end
    end
end

local function resolve_engine(algorithm)
    local engines = algorithm_engines[algorithm]
    if not engines or #engines == 0 then
        return nil, 'No available engine for algorithm: ' .. algorithm
    end
    return engines[1]
end

function M.hash(algorithm, data, options)
    options = options or {}
    local engine, err = resolve_engine(algorithm)
    if not engine then
        return Promise.reject(err)
    end
    return engine.hash(algorithm, data, options)
end

-- 自动生成快捷方法
local algos = {'md5', 'sha1', 'sha256', 'sha512'}
for _, algo in ipairs(algos) do
  M[algo] = function(data, opts)
    return M.hash(algo, data, opts)
  end
end

return M
