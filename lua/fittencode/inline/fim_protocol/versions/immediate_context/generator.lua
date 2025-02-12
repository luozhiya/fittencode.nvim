local Fn = require('fittencode.functional.fn')
local Editor = require('fittencode.document.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.document.position')
local Range = require('fittencode.document.range')

local ImmediateContextGenerator = {}
ImmediateContextGenerator.__index = ImmediateContextGenerator

function ImmediateContextGenerator:new()
    local obj = {}
    setmetatable(obj, ImmediateContextGenerator)
    return obj
end

function ImmediateContextGenerator:generate(buf, position, options)
    local prefix = Editor.get_text(buf, Range:new({ start = Position:new({ row = 0, col = 0 }), end_ = position }))
    local suffix = Editor.get_text(buf, Range:new({ start = position, end_ = Position:new({ row = -1, col = -1 }) }))
    local inputs = '!FCPREFIX!' .. prefix .. '!FCSUFFIX!' .. suffix .. '!FCMIDDLE!'
    local escaped_inputs = string.gsub(inputs, '"', '\\"')
    local prompt = {
        inputs = escaped_inputs,
        meta_datas = {
            filename = options.filename,
        },
    }
    return prompt
end

return ImmediateContextGenerator
