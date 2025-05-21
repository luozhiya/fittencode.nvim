local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')

local M = {}

local END_OF_TEXT_TOKEN = '<|endoftext|>' -- 文本结束标记

function M.generate(buf, position, options)
    local prefix = Fn.get_text(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = position }))
    local suffix = Fn.get_text(buf, Range.new({ start = position, end_ = Position.new({ row = -1, col = -1 }) }))
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

function M.parse(raw)
    local generated_text = vim.fn.substitute(raw.generated_text, END_OF_TEXT_TOKEN, '', 'g') or ''
    if generated_text == '' then
        return
    end
    return {
        completions = {
            {
                generated_text = generated_text,
            },
        },
    }
end

return M