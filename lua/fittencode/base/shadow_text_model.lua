--[[

为了避免重复调用 vim.api.nvim_buf_get_lines()，我们可以将文本内容缓存起来。

每一行都有一个 eol 标记，最末尾的行也有?

References:
- src/vscode/extensions/markdown-language-features/node_modules/vscode-languageserver-textdocument/lib/umd/main.js
- resources/app/out/vs/workbench/api/node/extensionHostProcess.js
- src/vs/workbench/api/common/extHostDocumentData.ts

--]]

local Position = require('fittencode.base.position')
local Fn = require('fittencode.base.fn')

---@class FittenCode.ShadowTextModel
---@field lines string[]
---@field eol string
---@field eol_length integer
---@field computed FittenCode.ShadowTextModel.Computed
local ShadowTextModel = {}
ShadowTextModel.__index = ShadowTextModel

---@class FittenCode.ShadowTextModel.Computed
---@field utf_line table<lsp.PositionEncodingKind, integer>
---@field utf_indices table<lsp.PositionEncodingKind, table<integer, integer>>
---@field sum_index table<lsp.PositionEncodingKind, integer>
---@field sum_prefix table<lsp.PositionEncodingKind, table<integer, integer>>
---@field full_text? string
---@field layouts FittenCode.EncodedStringLayout[]

---@class FittenCode.ShadowTextModel.InitializeOptions
---@field lines string[]
---@field eol string

---@param options FittenCode.ShadowTextModel.InitializeOptions
function ShadowTextModel.new(options)
    assert(options)
    local self = setmetatable({}, ShadowTextModel)
    self:_initialize(options)
    return self
end

---@param options FittenCode.ShadowTextModel.InitializeOptions
function ShadowTextModel:_initialize(options)
    assert(options and options.lines and options.eol and (options.eol == '\n' or options.eol == '\r' or options.eol == '\r\n'))
    self.lines = options.lines
    self.eol = options.eol
    self.eol_length = #self.eol
    self.computed = {
        utf_line = { ['utf-8'] = -1, ['utf-16'] = -1, ['utf-32'] = -1 },
        utf_indices = { ['utf-8'] = {}, ['utf-16'] = {}, ['utf-32'] = {} },
        sum_index = { ['utf-8'] = -1, ['utf-16'] = -1, ['utf-32'] = -1 },
        sum_prefix = { ['utf-8'] = {}, ['utf-16'] = {}, ['utf-32'] = {} },
        full_text = nil,
        layouts = {}
    }
end

---@param encoding lsp.PositionEncodingKind
---@param line integer
function ShadowTextModel:_compute_lines(encoding, line)
    if self.computed.utf_line[encoding] >= line then
        return
    end
    for i = self.computed.utf_line[encoding] + 1, line do
        local pi = self:_get_layout(i)
        self.computed.utf_indices[encoding][i + 1] = Fn.byte_to_utfindex(pi, encoding)
    end
    self.computed.utf_line[encoding] = line
end

---@param encoding lsp.PositionEncodingKind
---@param line integer
---@return integer
function ShadowTextModel:_get_utf_index(encoding, line)
    self:_compute_lines(encoding, line)
    return assert(self.computed.utf_indices[encoding][line + 1])
end

---@param encoding lsp.PositionEncodingKind
---@param line integer
function ShadowTextModel:_compute_prefix_sum(encoding, line)
    if self.computed.sum_index[encoding] >= line then
        return
    end
    for i = self.computed.sum_index[encoding] + 1, line do
        self.computed.sum_prefix[encoding][i + 1] = (self.computed.sum_prefix[encoding][i] or 0) + self:_get_utf_index(encoding, i) + self.eol_length
    end
    self.computed.sum_index[encoding] = line
end

---@param encoding lsp.PositionEncodingKind
---@param line integer
function ShadowTextModel:_get_prefix_sum(encoding, line)
    self:_compute_prefix_sum(encoding, line)
    return self.computed.sum_prefix[encoding][line + 1 - 1] or 0
end

---@param line integer 0-based
---@return string
function ShadowTextModel:line_at(line)
    return self.lines[line + 1]
end

function ShadowTextModel:line_count()
    return #self.lines
end

---@param encoding lsp.PositionEncodingKind
---@param position FittenCode.Position
---@return FittenCode.Position
function ShadowTextModel:_validate_position(encoding, position)
    if #self.lines == 0 then
        return Position.of(0, 0)
    end
    local line, character = position.row, position.col
    if line < 0 then
        line = 0
        character = 0
    elseif line >= #self.lines then
        line = #self.lines - 1
        character = self:_get_utf_index(encoding, line)
    else
        local max_character = self:_get_utf_index(encoding, line)
        if character < 0 then
            character = 0
        elseif character > max_character then
            character = max_character
        end
    end
    return Position.of(line, character)
end

---@param encoding lsp.PositionEncodingKind
---@param offset integer
---@return integer
function ShadowTextModel:_validate_offset(encoding, offset)
    if offset < 0 then
        return 0
    elseif offset >= self:_get_prefix_sum(encoding, #self.lines - 1) then
        return self:_get_prefix_sum(encoding, #self.lines - 1)
    end
    return offset
end

---@param encoding lsp.PositionEncodingKind
---@param offset integer
---@return FittenCode.Position
function ShadowTextModel:position_at(encoding, offset)
    offset = self:_validate_offset(encoding, offset)
    local low = 0
    local high = #self.lines - 1
    local mid = 0
    local mid_stop = 0
    local mid_start = 0
    while low < high do
        mid = low + (high - low + 1) / 2
        mid_stop = self:_get_prefix_sum(encoding, mid)
        mid_start = mid_stop - self:_get_utf_index(encoding, mid)
        if offset < mid_start then
            high = mid - 1
        elseif offset >= mid_stop then
            low = mid + 1
        else
            break
        end
    end
    local index = mid
    local remainder = offset - mid_start
    local line_length = self:_get_utf_index(encoding, index)
    return Position.of(index, math.min(line_length, remainder))
end

---@param encoding lsp.PositionEncodingKind
---@param position FittenCode.Position
---@return integer
function ShadowTextModel:offset_at(encoding, position)
    position = self:_validate_position(encoding, position)
    return self:_get_prefix_sum(encoding, position.row - 1) + position.col
end

---@param line integer
---@return FittenCode.EncodedStringLayout
function ShadowTextModel:_get_layout(line)
    if not self.computed.layouts[line + 1] then
        self.computed.layouts[line + 1] = Fn.encoded_layout(self.lines[line + 1])
    end
    return self.computed.layouts[line + 1]
end

---@param encoding? lsp.PositionEncodingKind
---@param range? FittenCode.Range
---@return string
function ShadowTextModel:get_text(encoding, range)
    if not range then
        if not self.computed.full_text then
            self.computed.full_text = table.concat(self.lines, self.eol)
        end
        return self.computed.full_text
    end
    assert(encoding)
    local result_lines = {}
    -- part 1
    local start_pi = self:_get_layout(range.start.row)
    local start_byte_index = Fn.utf_to_byteindex(start_pi, encoding, range.start.col + 1) - 1
    local remaning = self:line_at(range.start.row):sub(start_byte_index)
    result_lines[#result_lines + 1] = remaning
    -- part 2
    for i = range.start.row + 1, range.end_.row - 1 do
        result_lines[#result_lines + 1] = self.lines[i + 1]
    end
    -- part 3
    local end_pi = self:_get_layout(range.end_.row)
    local end_byte_index = Fn.utf_to_byteindex(end_pi, encoding, range.end_.col + 1) - 1
    end_byte_index = end_byte_index - 1
    if end_byte_index ~= -1 then
        remaning = self:line_at(range.end_.row):sub(1, end_byte_index)
        result_lines[#result_lines + 1] = remaning
    end
    return table.concat(result_lines, self.eol)
end

-- function M.normalize_range(buf, range)
--     if range.start.col == 2147483647 then
--         range.start.col = -1
--     end
--     if range.end_.col == 2147483647 then
--         range.end_.col = -1
--     end
--     range:sort()

--     local start_line = M.line_at(buf, range.start.row)
--     if not start_line then
--         return
--     end
--     local end_line = M.line_at(buf, range.end_.row)
--     if not end_line then
--         return
--     end
--     if range.start.col > #start_line or range.end_.col > #end_line then
--         return
--     end

--     range.start = M.round_start(buf, range.start)
--     range.end_ = M.round_end(buf, range.end_)
--     return range
-- end

return ShadowTextModel
