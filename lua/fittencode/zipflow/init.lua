--[[
local zf = require('zipflow')

----------------------------
-- 文本数据
----------------------------

zf.compress("Hello World!", {
    format = 'gzip',
    level = 9,
    input_type = 'data'
}):forward(function(compressed)
    print("压缩后大小:", #compressed)
end):catch(function(err)
    print("压缩失败:", err)
end)

----------------------------
-- 文件和目录
----------------------------

-- 简单压缩
zf.compress("input.txt", {
    output = "output.gz",
    level = 9,
    preserve = true
})

-- 加密压缩
zf.compress("secure.key", {
    output = "secure.gz",
    encryption = {
        password = "secret123",
        method = "AES256"
    },
    threads = 4
})

-- 压缩目录
zf.compress("/data/reports", {
    format = 'tar.gz',
    input_type = "directory",
}):forward(function(result)
    print("Directory compressed:", result.path)
end)

-- 解压操作
zf.decompress("archive.tar.gz", {
    preserve_permissions = true
})

--]]

local M = {}

local Promise = require('fittencode.concurrency.promise')
local Router = require('zipflow.router')
local Validator = require('zipflow.validator')

-- 输入类型检测
-- uv.aliases.fs_stat_types:
-- | "file"
-- | "directory"
-- | "link"
-- | "fifo"
-- | "socket"
-- | "char"
-- | "block"
local function detect_input_type(input)
    if type(input) ~= 'string' then
        return
    end
    local stat = vim.uv.fs_stat(input)
    if stat then
        if stat.type == 'file' or stat.type == 'directory' then
            return stat.type
        else
            return
        end
    end
    return 'data'
end

-- 统一入口函数
local function process(op_type, input, opts)
    return Promise.new(function(resolve, reject)
        opts = opts or {}
        opts.operation = op_type

        -- 自动检测输入类型
        if not opts.input_type then
            opts.input_type = detect_input_type(input)
        end

        -- 参数校验
        local ok, _ = Validator.validate(opts)
        if not ok then return reject(_) end

        -- 选择引擎
        local engine, _ = Router.select_engine(opts)
        if not engine then return reject(_) end

        -- 执行操作
        local processor = op_type == 'compress'
            and engine.compress
            or engine.decompress

        processor(input, opts)
            :forward(resolve)
            :catch(reject)
    end)
end

function M.compress(input, opts)
    return process('compress', input, opts)
end

function M.decompress(input, opts)
    return process('decompress', input, opts)
end

return M
