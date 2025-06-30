--[[

Model 的设计思路：
- 一个 Session 对应一个 Model
- Model 一次有很多个 CompletionModel 代表很多个补全选项，目前只支持一个

]]

local IncModel = require('fittencode.inline.model.inccmp.model')
local EditModel = require('fittencode.inline.model.editcmp.model')
local Log = require('fittencode.log')

---@class FittenCode.Inline.Model
---@field buf integer
---@field position FittenCode.Position
---@field selected_completion_index? integer
---@field completions FittenCode.Inline.IncrementalCompletion[] | FittenCode.Inline.EditCompletion[]
---@field completion_models FittenCode.Inline.EditCompletion.Model[] | FittenCode.Inline.IncrementalCompletion.Model[]
local Model = {}
Model.__index = Model

---@param options FittenCode.Inline.Model.InitialOptions
function Model.new(options)
    local self = setmetatable({}, Model)
    self:_initialize(options)
    return self
end

---@class FittenCode.Inline.Model.InitialOptions
---@field buf number
---@field position FittenCode.Position
---@field mode FittenCode.Inline.CompletionMode
---@field completions FittenCode.Inline.IncrementalCompletion[] | FittenCode.Inline.EditCompletion[]

---@param options FittenCode.Inline.Model.InitialOptions
function Model:_initialize(options)
    self.buf = options.buf
    self.position = options.position
    self.selected_completion_index = nil
    self.mode = options.mode

    self.completions = vim.deepcopy(options.completions)

    local Class = self.mode == 'editcmp' and EditModel or IncModel
    self.completion_models = {}
    for _, completion in ipairs(self.completions) do
        self.completion_models[#self.completion_models + 1] = Class.new({ buf = self.buf, position = self.position, completion = completion })
    end

    -- 如果要支持多 completion 则需要修改这里，弹出一个对话框让用户选择
    self:set_selected_completion(1)
end

---@return FittenCode.Inline.IncrementalCompletion.Model | FittenCode.Inline.EditCompletion.Model
function Model:selected_completion()
    return assert(self.completion_models[assert(self.selected_completion_index)], 'No completion model selected')
end

---@param scope FittenCode.Inline.AcceptScope
function Model:accept(scope)
    assert(self:selected_completion()):accept(scope)
end

function Model:revoke()
    assert(self:selected_completion()):revoke()
end

function Model:is_complete()
    return assert(self:selected_completion()):is_complete()
end

---@class FittenCode.Inline.Model.UpdateData
---@field segments FittenCode.Inline.Segments

---@param data FittenCode.Inline.Model.UpdateData
function Model:update(data)
    local segments = data.segments or {}
    for _, s in pairs(segments) do
        self.completion_models[tonumber(_)]:update({ segment = s })
    end
end

-- 一旦开始 comletion 则不允许再选择其他的 completion
-- TODO:?
---@param index integer
function Model:set_selected_completion(index)
    if self.selected_completion_index ~= nil then
        return
    end
    self.selected_completion_index = index
end

---@return FittenCode.Inline.IncrementalCompletion.Model.Snapshot | FittenCode.Inline.EditCompletion.Model.Snapshot
function Model:snapshot()
    return assert(self:selected_completion()):snapshot()
end

---@param key string
function Model:is_match_next_char(key)
    return key == assert(self:selected_completion()):get_next_char()
end

function Model:get_col_delta()
    return assert(self:selected_completion()):get_col_delta()
end

---@return string[]
function Model:get_text()
    local text = {}
    for _, completion in ipairs(self.completion_models) do
        text[#text + 1] = completion:get_text()
    end
    return text
end

function Model:any_accepted()
    return assert(self:selected_completion()):any_accepted()
end

return Model
