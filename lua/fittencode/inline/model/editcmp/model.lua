local Log = require('fittencode.log')
local F = require('fittencode.fn.buf')
local Diff = require('fittencode.fn.diff')

---@class FittenCode.Inline.EditCompletion.Model
---@field merge_method string
---@field commit_index integer
---@field start_line integer
---@field end_line integer
---@field after_line integer
---@field lines string[]
---@field hunks FittenCode.Diff.Hunk[]
---@field gap_common_hunks FittenCode.Diff.CommonHunk[]
---@field snapshot function
---@field accept fun(self: FittenCode.Inline.EditCompletion.Model, scope: FittenCode.Inline.EditAcceptScope)
---@field is_complete function
---@field revoke function
local Model = {}
Model.__index = Model

---@class FittenCode.Inline.EditCompletion.Model.InitialOptions
---@field buf integer
---@field position FittenCode.Position
---@field completion FittenCode.Inline.EditCompletion

---@param options FittenCode.Inline.EditCompletion.Model.InitialOptions
function Model.new(options)
    assert(options and options.buf and options.position and options.completion, 'Invalid options')
    local buf, position, completion = options.buf, options.position, options.completion
    local self = setmetatable({}, Model)
    Log.debug('Edit completion model created, completion = {}', completion)
    assert(completion.lines)

    self.lines = vim.deepcopy(completion.lines)
    if completion.after_line then
        self.merge_method = 'after_line'
        self.after_line = completion.after_line
        self.hunks, self.gap_common_hunks = Diff.diff_block({}, completion.lines)
    else
        self.merge_method = 'line_range'
        self.start_line = completion.start_line
        self.end_line = completion.end_line
        local old_lines = F.get_lines_by_line_range(buf, self.start_line, self.end_line)
        self.hunks, self.gap_common_hunks = Diff.diff_block(old_lines, completion.lines)
    end
    self.commit_index = 0
    return self
end

---@class FittenCode.Inline.EditCompletion.Model.Snapshot
---@field after_line integer
---@field start_line integer
---@field end_line integer
---@field commit_index integer
---@field hunks FittenCode.Diff.Hunk[]
---@field gap_common_hunks FittenCode.Diff.CommonHunk[]
---@field lines string[]

---@return FittenCode.Inline.EditCompletion.Model.Snapshot
function Model:snapshot()
    local result = {
        after_line = self.after_line,
        start_line = self.start_line,
        end_line = self.end_line,
        commit_index = self.commit_index,
        hunks = vim.deepcopy(self.hunks),
        gap_common_hunks = vim.deepcopy(self.gap_common_hunks),
        lines = vim.deepcopy(self.lines),
    }
    return result
end

---@param scope string
function Model:is_scope_valid(scope)
    local supported_scopes = { 'all', 'hunk' }
    return vim.tbl_contains(supported_scopes, scope)
end

---@param scope FittenCode.Inline.EditAcceptScope
function Model:accept(scope)
    if not self:is_scope_valid(scope) then
        Log.error('Invalid scope: ' .. scope)
        return
    end
    if scope == 'hunk' then
        self.commit_index = self.commit_index + 1
    elseif scope == 'all' then
        self.commit_index = #self.hunks
    end
end

function Model:is_complete()
    return self.commit_index == #self.hunks
end

function Model:revoke()
    if self.commit_index == 0 then
        return
    end
    assert(self.commit_index ~= #self.hunks)
    self.commit_index = self.commit_index - 1
end

function Model:any_accepted()
    return self.commit_index > 0
end

return Model
