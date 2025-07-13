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
local Log = require('fittencode.log')

-- substring in js
-- 包含 start 不包含 finish
-- 0-based
local function substring(str, start, finish)
    -- Convert to 1-based indexing (Lua's default)
    local start_pos = start + 1
    local finish_pos = finish or #str -- default to end of string if finish is nil

    -- Handle negative values (JavaScript treats them as 0)
    if start_pos < 1 then start_pos = 1 end
    if finish_pos < 1 then finish_pos = 1 end

    -- Handle cases where start > finish (JavaScript swaps them)
    if start_pos > finish_pos then
        start_pos, finish_pos = finish_pos, start_pos
    end

    -- Ensure positions don't exceed string length
    if start_pos > #str + 1 then start_pos = #str + 1 end
    if finish_pos > #str + 1 then finish_pos = #str + 1 end

    Log.notify_debug('substring, str = {}, start_pos = {}, finish_pos = {}', str, start_pos, finish_pos)

    return string.sub(str, start_pos, finish_pos)
end

---@class FittenCode.ShadowTextModel
---@field lines string[]
---@field eol string
---@field eol_length integer
---@field version? number
---@field buffer? integer
---@field context_encoding? lsp.PositionEncodingKind
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
---@field version? number
---@field buffer? integer
---@field encoding? lsp.PositionEncodingKind

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
    assert(#self.lines > 0)
    self.eol = options.eol
    self.eol_length = #self.eol
    self.version = options.version
    self.buffer = options.buffer
    self.context_encoding = options.encoding
    self.computed = {
        utf_line = { ['utf-8'] = -1, ['utf-16'] = -1, ['utf-32'] = -1 },
        utf_indices = { ['utf-8'] = {}, ['utf-16'] = {}, ['utf-32'] = {} },
        sum_index = { ['utf-8'] = -1, ['utf-16'] = -1, ['utf-32'] = -1 },
        sum_prefix = { ['utf-8'] = {}, ['utf-16'] = {}, ['utf-32'] = {} },
        full_text = nil,
        layouts = {}
    }
end

function ShadowTextModel.from_buffer(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return ShadowTextModel.new({
        lines = lines,
        -- eol = vim.lsp._buf_get_line_ending(buf),
        eol = '\n', -- TODO: 这里应该根据文件类型自动判断，目前为了简化逻辑使用统一的换行符
        buffer = buf,
        version = Fn.version(buf)
    })
end

---@param encoding lsp.PositionEncodingKind
function ShadowTextModel:update_context_encoding(encoding)
    local prev = self.context_encoding
    self.context_encoding = encoding
    return prev
end

---@param encoding lsp.PositionEncodingKind
---@param fx function
---@return any
function ShadowTextModel:with(encoding, fx)
    local prev = self.context_encoding
    self.context_encoding = encoding
    local result = fx()
    self.context_encoding = prev
    return result
end

---@param encoding lsp.PositionEncodingKind
---@param line integer
function ShadowTextModel:_compute_lines(encoding, line)
    if self.computed.utf_line[encoding] >= line then
        return
    end
    for i = self.computed.utf_line[encoding] + 1, line do
        local pi = self:_get_layout(i)
        self.computed.utf_indices[encoding][i + 1] = Fn.byte_to_utfindex(pi, encoding)[2]
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

-- 将 encoding 指定的 unitcode 转换成 Position
---@param offset integer
---@param encoding? lsp.PositionEncodingKind
---@return FittenCode.Position
function ShadowTextModel:position_at(offset, encoding)
    encoding = encoding or self.context_encoding
    assert(encoding)
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

-- 将 encoding 指定 Position 转换成 codeunit 索引
---@param position FittenCode.Position
---@param encoding? lsp.PositionEncodingKind
---@return integer
function ShadowTextModel:offset_at(position, encoding)
    encoding = encoding or self.context_encoding
    assert(encoding)
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

--[[

获取 encoding 指定的 range 范围内的文本内容

- 从 0 开始计数
- 如果 range 为空，返回全部文本内容
- range 可以是 -1, 2147483647 这样的值，这里将其解析成最大值
- 包含 range 的 start
- 不包含 range 的 end
- range.start == range.end_ 表示空 range, 返回空字符串

]]
---@param options? { encoding?: lsp.PositionEncodingKind, range?: FittenCode.Range}
---@return string
function ShadowTextModel:get_text(options)
    Log.notify_debug('get_text = {}', options)
    local range = options and options.range
    if not range then
        if not self.computed.full_text then
            self.computed.full_text = table.concat(self.lines, self.eol)
        end
        return self.computed.full_text
    end
    local encoding = options and options.encoding or self.context_encoding
    assert(encoding)
    range = self:normalize(range, encoding)
    Log.notify_debug('range = {}', range)
    if range:is_empty() then
        Log.notify_debug('empty range')
        return ''
    end
    if range:is_single_line() then
        local start_byte_index = Fn.utf_to_byteindex(self:_get_layout(range.start.row), encoding, range.start.col + 1)[1] - 1
        local end_byte_index = Fn.utf_to_byteindex(self:_get_layout(range.end_.row), encoding, range.end_.col + 1)[1] - 1
        Log.notify_debug('start_byte_index = {}, end_byte_index = {}', start_byte_index, end_byte_index)
        return substring(self:line_at(range.start.row), start_byte_index, end_byte_index)
    end
    local result_lines = {}
    -- part 1
    local start_byte_index = Fn.utf_to_byteindex(self:_get_layout(range.start.row), encoding, range.start.col + 1)[1] - 1
    -- local remaning = self:line_at(range.start.row):sub(start_byte_index)
    local remaning = substring(self:line_at(range.start.row), start_byte_index)
    Log.notify_debug('start_byte_index = {}, remaning = {}', start_byte_index, remaning)
    result_lines[#result_lines + 1] = remaning
    -- part 2
    for i = range.start.row + 1, range.end_.row - 1 do
        result_lines[#result_lines + 1] = self.lines[i + 1]
    end
    -- part 3
    local end_byte_index = Fn.utf_to_byteindex(self:_get_layout(range.end_.row), encoding, range.end_.col + 1)[2] - 1
    -- remaning = self:line_at(range.end_.row):sub(1, end_byte_index)
    remaning = substring(self:line_at(range.end_.row), 0, end_byte_index)
    Log.notify_debug('end_byte_index = {}, remaning = {}', end_byte_index, remaning)
    result_lines[#result_lines + 1] = remaning
    return table.concat(result_lines, self.eol)
end

-- 将 from_encoding 的 position 映射到 to_encoding 的位置
---@param from_encoding lsp.PositionEncodingKind
---@param to_encoding lsp.PositionEncodingKind
---@param position FittenCode.Position
---@return FittenCode.Position
function ShadowTextModel:map(from_encoding, to_encoding, position)
    local row = position.row
    local col = Fn.equivalent_unit_range(self:_get_layout(row), from_encoding, to_encoding, position.col)[1]
    return Position.of(row, col)
end

-- 向前移动一个 character，返回的 position 指向前一个字符的开始 codeunit
---@param position FittenCode.Position
---@param encoding? lsp.PositionEncodingKind
---@return FittenCode.Position
function ShadowTextModel:shift_right(position, encoding)
    encoding = encoding or self.context_encoding
    assert(encoding)
    local col = Fn.round_end(self:_get_layout(position.row), encoding, position.col)
    -- local col_next = Fn.round_end(self:_get_layout(position.row), encoding, col + 1)
    return Position.of(position.row, col + 1)
end

-- 向后移动一个 character，返回的 position 指向后一个字符的最末 codeunit
---@param encoding lsp.PositionEncodingKind
---@param position FittenCode.Position
---@return FittenCode.Position
function ShadowTextModel:shift_left(position, encoding)
    encoding = encoding or self.context_encoding
    assert(encoding)
    local col = Fn.round_start(self:_get_layout(position.row), encoding, position.col)
    return Position.of(position.row, col > 0 and col - 1 or 0)
end

function ShadowTextModel:round_start(position, encoding)
    encoding = encoding or self.context_encoding
    assert(encoding)
    return Position.of(position.row, Fn.round_start(self:_get_layout(position.row), encoding, position.col))
end

function ShadowTextModel:round_end(position, encoding)
    encoding = encoding or self.context_encoding
    assert(encoding)
    return Position.of(position.row, Fn.round_end(self:_get_layout(position.row), encoding, position.col))
end

-- 正则化指定 encoding 的 range
-- Neovim 支持 -1 指定，这里将 -1 解析成最大值
-- Neovim 有时会返回 2147483647，这里也将其解析成最大值
---@param encoding lsp.PositionEncodingKind
---@param range FittenCode.Range
function ShadowTextModel:normalize(range, encoding)
    encoding = encoding or self.context_encoding
    assert(encoding)
    if range.start.row == -1 then
        range.start.row = #self.lines - 1
    end
    if range.end_.row == -1 then
        range.end_.row = #self.lines - 1
    end
    if range.start.col == -1 or range.start.col == 2147483647 then
        range.start.col = Fn.byte_to_utfindex(self:_get_layout(range.start.row), encoding)[2]
    end
    if range.end_.col == -1 or range.end_.col == 2147483647 then
        range.end_.col = Fn.byte_to_utfindex(self:_get_layout(range.end_.row), encoding)[2]
    end
    range:sort()
    range.start.col = Fn.round_start(self:_get_layout(range.start.row), encoding, range.start.col)
    range.end_.col = Fn.round_end(self:_get_layout(range.end_.row), encoding, range.end_.col)
    return range
end

function ShadowTextModel:wordcount()
    assert(self.buffer)
    return Fn.wordcount(self.buffer)
end

return ShadowTextModel
