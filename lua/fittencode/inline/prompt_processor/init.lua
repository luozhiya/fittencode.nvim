local Hash = require('fittencode.hash')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')
local Range = require('fittencode.range')
local Config = require('fittencode.config')

---@class FittenCode.Inline.PromptProcessor
local PromptProcessor = {}
PromptProcessor.__index = PromptProcessor

---@return FittenCode.Inline.PromptProcessor
function PromptProcessor:new(options)
    local obj = {}
    setmetatable(obj, self)
    return obj
end

---@param options FittenCode.Inline.GeneratePromptOptions
function PromptProcessor:generate(options)
    assert(options.buf)
    assert(options.position)
    local buf = options.buf
    local position = options.position

    Fn.schedule_call(options.on_create)
    if options.api_version == 'v2' then
        self:generate_prompt_v2(buf, position, options)
    elseif options.api_version == 'v1' then
        self:generate_prompt_v1(buf, position, options)
    end
end

---@param buf number
---@param position {row: number, col: number}
---@param options FittenCode.Inline.GeneratePromptOptions
---@return FittenCode.Inline.Prompt?
function PromptProcessor:generate_prompt_v2(buf, position, options)
    -- 实现 v2 版本的提示生成逻辑
    -- 这里只是一个示例，实际逻辑需要根据具体需求编写
    return { content = "Generated prompt for v2" }
end

---@param buf number
---@param position {row: number, col: number}
---@param options FittenCode.Inline.GeneratePromptOptions
---@return FittenCode.Inline.Prompt?
function PromptProcessor:generate_prompt_v1(buf, position, options)
    -- 实现 v1 版本的提示生成逻辑
    -- 这里只是一个示例，实际逻辑需要根据具体需求编写
    return { content = "Generated prompt for v1" }
end

return PromptProcessor
