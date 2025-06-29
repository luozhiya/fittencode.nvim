local Log = require('fittencode.log')
local F = require('fittencode.fn.buf')
local Diff = require('fittencode.fn.diff')

---@class FittenCode.Inline.EditCompletion.Model
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
---@field merge string
---@field commit_index integer
---@field start_line integer
---@field end_line integer
---@field after_line integer
---@field lines string[]
---@field hunks FittenCode.Diff.Hunk[]
---@field gap_common_hunks FittenCode.Diff.CommonHunk[]
local Model = {}
Model.__index = Model

function Model.new(buf, position, completion)
    local self = setmetatable({}, Model)
    Log.debug('Edit completion model created, completion = {}', completion)
    assert(completion.lines)

    self.lines = vim.deepcopy(completion.lines)
    if completion.after_line then
        self.merge = 'after_line'
        self.after_line = completion.after_line
        self.hunks, self.gap_common_hunks = Diff.diff_block({}, completion.lines)
    else
        self.merge = 'line_range'
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

---@param scope 'all' | 'hunk'
function Model:accept(scope)
    local supported_scopes = { 'all', 'hunk' }
    if not vim.tbl_contains(supported_scopes, scope) then
        Log.error('Unsupported scope: ' .. scope)
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

return Model
