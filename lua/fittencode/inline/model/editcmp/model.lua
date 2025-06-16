local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')
local F = require('fittencode.fn.buf')

---@class FittenCode.Inline.EditCompletion.Model
---@field snapshot function
---@field accept function
---@field is_complete function
---@field revoke function
---@field merge string
local Model = {}
Model.__index = Model

function Model.new(buf, position, completion)
    local self = setmetatable({}, Model)
    Log.debug('Edit completion model created, completion = {}', completion)
    assert(completion.replace_range)
    assert(completion.replace_lines)
    local start_pos = completion.replace_range.start
    local end_pos = completion.replace_range.end_

    local start_line = assert(F.line_at(buf, start_pos.row))
    if start_pos == end_pos and start_line.range.end_.col + 1 == start_pos.col then
        self.merge = 'simple'
    else
        self.merge = 'complex'
    end

    -- simple 模式直接插入文本即可，不涉及 diff 计算
    -- 在 start_line 的末尾插入 completion.replace_lines
    -- 甚至可以让其退化成 inccmp ?

    return self
end

function Model:snapshot()
end

---@param scope 'all' | 'hunk'
function Model:accept(scope)
    local supported_scopes = { 'all', 'hunk' }
    if not vim.tbl_contains(supported_scopes, scope) then
        error('Unsupported scope: '.. scope)
    end
    if self.merge == 'simple' and scope == 'hunk' then
        error('Unsupported scope: hunk for simple merge')
    end
end

function Model:is_complete()
end

function Model:revoke()
end

return Model
