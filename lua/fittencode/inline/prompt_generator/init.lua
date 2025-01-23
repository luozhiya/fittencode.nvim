local Hash = require('fittencode.hash')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')
local Range = require('fittencode.range')
local Config = require('fittencode.config')
local V1 = require('fittencode.inline.prompt_generator.v1')
local V2 = require('fittencode.inline.prompt_generator.v2')

---@class FittenCode.Inline.PromptGenerator
---@field v1 FittenCode.Inline.PromptGenerator.V1
---@field v2 FittenCode.Inline.PromptGenerator.V2

---@class FittenCode.Inline.PromptGenerator
local PromptGenerator = {}
PromptGenerator.__index = PromptGenerator

---@return FittenCode.Inline.PromptGenerator
function PromptGenerator:new()
    local obj = {
        v1 = V1:new(),
        v2 = V2:new()
    }
    setmetatable(obj, self)
    return obj
end

---@param buf number
---@param position FittenCode.Position
---@param options FittenCode.Inline.GeneratePromptOptions
function PromptGenerator:generate(buf, position, options)
    if options.api_version == 'vim' then
        return self.v1:generate(buf, position, options)
    elseif options.api_version == 'vscode' then
        return self.v2:generate(buf, position, options)
    else
        Log.error('Invalid API version: ' .. options.api_version)
        return
    end
end

return PromptGenerator
