--[[
local zf = require('zipflow')

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
--]]

local M = {}
local Router = require('zipflow.router')
local Validator = require('zipflow.validator')

function M.compress(input, output, opts)
    opts = opts or {}
    opts.operation = 'compress'
    opts.input = input
    opts.output = output

    Validator.validate_input(opts)
    local engine = Router.select_engine(opts)
    return engine.compress(opts)
end

function M.decompress(input, output, opts)
    opts = opts or {}
    opts.operation = 'decompress'
    opts.input = input
    opts.output = output

    Validator.validate_input(opts)
    local engine = Router.select_engine(opts)
    return engine.decompress(opts)
end

return M
