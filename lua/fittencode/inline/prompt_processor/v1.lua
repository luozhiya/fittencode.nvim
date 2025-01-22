local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')
local Range = require('fittencode.range')

local function generate_prompt_v1(buf, position, options)
    local prefix = Editor.get_text(buf, Range:new({ start = Position:new({ row = 0, col = 0 }), termination = position }))
    local suffix = Editor.get_text(buf, Range:new({ start = position, termination = Position:new({ row = -1, col = -1 }) }))
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

return {
    generate_prompt = generate_prompt_v1,
}
