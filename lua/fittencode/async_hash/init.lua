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

local engine_priority = {
    ['libcrypto']   = 100, -- FFI实现的最高优先级
    ['openssl-cli'] = 90,  -- OpenSSL命令行
    ['sum-command'] = 80,  -- 系统sum命令
    ['native']      = 70   -- 纯Lua实现
}

local function sort_engines(a, b)
    -- 优先按分类权重排序
    if a.priority ~= b.priority then
        return a.priority > b.priority
    end
    -- 同分类下按性能评分排序
    return a.features.performance > b.features.performance
end

local function load_engines()
    -- 引擎列表
    local engine_names = {
        'openssl',
        'md5sum',
        'sha1sum',
        'sha256sum',
        'libcrypto',
        'native',
    }

    local candidates = {}
    -- 加载引擎模块
    for _, name in ipairs(engine_names) do
        local ok, mod = pcall(require, 'fittencode.async_hash.engines.' .. name)
        if ok then
            table.insert(candidates, mod)
        end
    end

    local available = {}
    for _, engine in ipairs(candidates) do
        if engine.is_available() then
            -- 自动设置优先级权重
            engine.priority = engine_priority[engine.category] or 50
            table.insert(available, engine)
        end
    end

    table.sort(available, sort_engines)
    return available
end

-- 根据 Hash 算法分类引擎
local algorithm_engine_map = {}

local M = {}

function M.setup()
    -- 初始化时加载排序后的引擎
    local engines = load_engines()

    for _, engine in ipairs(engines) do
        for _, algo in ipairs(engine.algorithms) do
            if not algorithm_engine_map[algo] then
                algorithm_engine_map[algo] = {
                    primary = engine, -- 主选引擎
                    fallbacks = {}    -- 备选引擎
                }
            else
                table.insert(algorithm_engine_map[algo].fallbacks, engine)
            end
        end
    end
end

function M.get_engine(algorithm, options)
    options = options or {}
    local entry = algorithm_engine_map[algorithm]
    if not entry then return nil, 'Unsupported algorithm' end

    -- 根据选项动态选择
    if options.prefer then
        for _, engine in ipairs(entry.fallbacks) do
            if engine.name == options.prefer then
                return engine
            end
        end
    end

    -- 自动选择主引擎
    return entry.primary
end

function M.hash(algorithm, data, options)
    local engine, err = M.get_engine(algorithm, options)
    if not engine then return Promise.reject(err) end
    return engine.hash(algorithm, data, options)
end

-- 自动生成快捷方法
local algos = { 'md5', 'sha1', 'sha256', 'sha512' }
for _, algo in ipairs(algos) do
    M[algo] = function(data, opts)
        return M.hash(algo, data, opts)
    end
end

return M
