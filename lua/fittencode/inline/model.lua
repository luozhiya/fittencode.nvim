--[[

Model 的设计思路：
- 一个 Session 对应一个 Model
- Model 一次有很多个 CompletionModel 代表很多个补全选项，目前只支持一个

]]

local IncModel = require('fittencode.inline.model.inccmp.model')
local EditModel = require('fittencode.inline.model.editcmp.model')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Range = require('fittencode.fn.range')
local Position = require('fittencode.fn.position')
local Unicode = require('fittencode.fn.unicode')

---@class FittenCode.Inline.Model
---@field buf number
---@field position FittenCode.Position
---@field response any
---@field selected_completion_index? number
---@field completions table<table<string, any>>
---@field completion_models table<number, FittenCode.Inline.EditCompletion.Model | FittenCode.Inline.IncrementalCompletion.Model>
local Model = {}
Model.__index = Model

function Model.new(options)
    local self = setmetatable({}, Model)
    self:_initialize(options)
    return self
end

function Model:_initialize(options)
    self.buf = options.buf
    self.position = options.position
    self.selected_completion_index = nil
    self.mode = options.mode

    self.completions = vim.deepcopy(options.completions)

    local Class = self.mode == 'editcmp' and EditModel or IncModel
    self.completion_models = {}
    for _, completion in ipairs(self.completions) do
        self.completion_models[#self.completion_models + 1] = Class.new(self.buf, self.position, completion)
    end

    -- 如果要支持多 completion 则需要修改这里，弹出一个对话框让用户选择
    self:set_selected_completion(1)
end

---@return FittenCode.Inline.IncrementalCompletion.Model | FittenCode.Inline.EditCompletion.Model
function Model:selected_completion()
    return assert(self.completion_models[assert(self.selected_completion_index)], 'No completion model selected')
end

---@param scope string
function Model:accept(scope)
    assert(self:selected_completion()):accept(scope)
end

function Model:revoke()
    assert(self:selected_completion()):revoke()
end

function Model:is_complete()
    return assert(self:selected_completion()):is_complete()
end

function Model:update(state)
    -- if #vim.tbl_keys(state) ~= #self.completion_models then
    --     return
    -- end
    -- for _, s in pairs(state) do
    --     self.completion_models[_]:update(s)
    -- end
end

-- 一旦开始 comletion 则不允许再选择其他的 completion
-- TODO:?
function Model:set_selected_completion(index)
    if self.selected_completion_index ~= nil then
        return
    end
    self.selected_completion_index = index
end

function Model:snapshot()
    return assert(self:selected_completion()):snapshot()
end

function Model:is_match_next_char(key)
    return key == assert(self:selected_completion()):get_next_char()
end

function Model:get_col_delta()
    return assert(self:selected_completion()):get_col_delta()
end

function Model:get_text()
    local text = {}
    for _, completion in ipairs(self.completion_models) do
        text[#text + 1] = completion:get_text()
    end
    return text
end

return Model
