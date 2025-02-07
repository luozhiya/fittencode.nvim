--[[
local zf = require('zipflow')

----------------------------
-- 压缩文本数据
----------------------------

zf.compress("Hello World!", {
    format = 'gzip',
    level = 9
}):forward(function(compressed)
    print("压缩后大小:", #compressed)
end):catch(function(err)
    print("压缩失败:", err)
end)

----------------------------
-- 压缩二进制数据
----------------------------
local binary_data = get_image_data()

zf.compress(binary_data, {
    format = 'zlib',
    input_type = 'binary'
}):forward(function(result)
    save_to_file(result, 'image.zlib')
end)

----------------------------
-- 压缩文件和目录
----------------------------

-- 简单压缩
zf.compress("input.txt", "output.gz", {
    level = 9,
    preserve = true
})

-- 加密压缩
zf.compress("data", "secure.zip", {
    encryption = {
        password = "secret123",
        method = "AES256"
    },
    threads = 4
})

-- 解压操作
zf.decompress("archive.tar.gz", "extracted", {
    preserve_permissions = true
})

----------------------------
-- 流式处理
----------------------------

local stream = zf.compress_stream('gzip', {level=6})

-- 分块输入
stream:send("Part1...")
stream:send("Part2...")
stream:send(nil) -- 结束输入

-- 分块接收输出
while true do
    local chunk = stream:receive()
    if not chunk then break end
    process_chunk(chunk)
end
--]]

local M = {}

local Promise = require('fittencode.concurrency.promise')
local Router = require('zipflow.router')
local Validator = require('zipflow.validator')

-- 输入类型检测
local function detect_input_type(input)
    if type(input) == 'string' then
        if vim.uv.fs_access(input, 'r') then
            return 'file'
        else
            return (#input < 1024 and not input:find('\0'))
                and 'text'
                or 'binary'
        end
    elseif type(input) == 'table' and input._is_stream then
        return 'stream'
    end
    error("Unsupported input type")
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
        local ok, err = Validator.validate_input(opts)
        if not ok then return reject(err) end

        -- 选择引擎
        local engine, err = Router.select_engine(opts)
        if not engine then return reject(err) end

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
