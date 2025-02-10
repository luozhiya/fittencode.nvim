local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')
local Range = require('fittencode.range')

---@class FittenCode.Inline.PromptGenerator.ImmediateContextGenerator
local ImmediateContextGenerator = {}
ImmediateContextGenerator.__index = ImmediateContextGenerator

function ImmediateContextGenerator:new()
    local obj = {}
    setmetatable(obj, ImmediateContextGenerator)
    return obj
end

function ImmediateContextGenerator:generate(buf, position, options)
    Fn.schedule_call(options.on_create)
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
    Fn.schedule_call(options.on_once, prompt)
end

return ImmediateContextGenerator
