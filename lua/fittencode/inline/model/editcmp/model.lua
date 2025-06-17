local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')
local F = require('fittencode.fn.buf')
local Diff = require('fittencode.fn.diff')

---@class FittenCode.Inline.EditCompletion.Model
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
---@field merge string
---@field accepted number
---@field hunks table
---@field gap_common_hunks table
---@field start_line number
---@field end_line number
---@field after_line number
local Model = {}
Model.__index = Model

function Model.new(buf, position, completion)
    local self = setmetatable({}, Model)
    Log.debug('Edit completion model created, completion = {}', completion)
    assert(completion.lines)

    if completion.after_line then
        self.merge = 'after_line'
        self.after_line = completion.after_line
        self.hunks, self.gap_common_hunks = Diff.diff_lines2({}, completion.lines)
    else
        self.merge = 'line_range'
        self.start_line = completion.start_line
        self.end_line = completion.end_line
        local old_lines = F.get_lines_by_line_range(buf, self.start_line, self.end_line)
        self.hunks, self.gap_common_hunks = Diff.diff_lines2(old_lines, completion.lines)
    end
    self.accepted = 0
    return self
end

function Model:snapshot()
    local result = {
        after_line = self.after_line,
        start_line = self.start_line,
        end_line = self.end_line,
        accepted = self.accepted,
        hunks = vim.deepcopy(self.hunks),
        gap_common_hunks = vim.deepcopy(self.gap_common_hunks),
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
        self.accepted = self.accepted + 1
    elseif scope == 'all' then
        self.accepted = #self.hunks
    end
end

function Model:is_complete()
    return self.accepted == #self.hunks
end

function Model:revoke()
    if self.accepted == 0 then
        return
    end
    assert(self.accepted ~= #self.hunks)
    self.accepted = self.accepted - 1
end

return Model
