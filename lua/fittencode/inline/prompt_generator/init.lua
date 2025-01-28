local Hash = require('fittencode.hash')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')
local Position = require('fittencode.position')
local Range = require('fittencode.range')
local Config = require('fittencode.config')
local ImmediateContext = require('fittencode.inline.prompt_generator.immediate_context')
local ProjectAware = require('fittencode.inline.prompt_generator.project_aware')

---@class FittenCode.Inline.PromptGenerator
---@field generators table<string, FittenCode.Inline.PromptGenerator.ImmediateContextGenerator|FittenCode.Inline.PromptGenerator.ProjectAwareGenerator>

---@class FittenCode.Inline.PromptGenerator
local PromptGenerator = {}
PromptGenerator.__index = PromptGenerator

---@param options {project_completion_service?: any}
---@return FittenCode.Inline.PromptGenerator
function PromptGenerator:new(options)
    local generators = {
        ['1'] = ImmediateContext:new(),
        ['2'] = ProjectAware:new({
            project_completion_service = options.project_completion_service,
        })
        -- 添加新版本时在此注册
    }
    local obj = {
        generators = generators
    }
    setmetatable(obj, self)
    return obj
end

---@param buf number
---@param position FittenCode.Position
---@param options FittenCode.Inline.GeneratePromptOptions
function PromptGenerator:generate(buf, position, options)
    local version = options.gos_version or '1'
    local generator = self.generators[version]

    if not generator then
        Log.error('Invalid API version: ' .. version)
        return
    end

    return generator:generate(buf, position, options)
end

return PromptGenerator