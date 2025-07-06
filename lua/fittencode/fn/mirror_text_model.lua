--[[

为了避免重复调用 vim.api.nvim_buf_get_lines()，我们可以将文本内容缓存起来。

每一行都有一个 eol 标记，最末尾的行也有?

References:
- src/vscode/extensions/markdown-language-features/node_modules/vscode-languageserver-textdocument/lib/umd/main.js
- resources/app/out/vs/workbench/api/node/extensionHostProcess.js

--]]

local Unicode = require('fittencode.fn.unicode')
local Position = require('fittencode.fn.position')

---@class FittenCode.MirrorTextModel
---@field lines string[]
---@field eol string
---@field eol_length integer
---@field computed FittenCode.MirrorTextModel.Computed
local MirrorTextModel = {}
MirrorTextModel.__index = MirrorTextModel

---@class FittenCode.MirrorTextModel.Computed
---@field u16_line integer
---@field u16_indices table<integer, integer>
---@field sum_index integer
---@field sum_prefix table<integer, integer>
---@field full_text? string
---@field layouts FittenCode.Unicode.MultiEncodingStringLayout[]

---@class FittenCode.MirrorTextModel.InitializeOptions
---@field lines string[]
---@field eol string

---@param options FittenCode.MirrorTextModel.InitializeOptions
function MirrorTextModel.new(options)
    assert(options)
    local self = setmetatable({}, MirrorTextModel)
    self:_initialize(options)
    return self
end

---@param options FittenCode.MirrorTextModel.InitializeOptions
function MirrorTextModel:_initialize(options)
    assert(options and options.lines and options.eol and (options.eol == '\n' or options.eol == '\r' or options.eol == '\r\n'))
    self.lines = options.lines
    self.eol = options.eol
    self.eol_length = #self.eol
    self.computed = {
        u16_line = -1,
        u16_indices = {},
        sum_index = -1,
        sum_prefix = {},
        full_text = nil,
        layouts = {}
    }
end

function MirrorTextModel:_compute_lines(target_line)
    if self.computed.u16_line >= target_line then
        return
    end
    for i = self.computed.u16_line + 1, target_line do
        local pi = self:_get_layout(i)
        self.computed.u16_indices[i + 1] = Unicode.byte_to_utfindex_by_layout(pi, 'utf-16')
    end
    self.computed.u16_line = target_line
end

function MirrorTextModel:_get_u16_index(line)
    self:_compute_lines(line)
    return assert(self.computed.u16_indices[line + 1])
end

function MirrorTextModel:_compute_prefix_sum(target_line)
    if self.computed.sum_index >= target_line then
        return
    end
    for i = self.computed.sum_index + 1, target_line do
        self.computed.sum_prefix[i + 1] = (self.computed.sum_prefix[i] or 0) + self:_get_u16_index(i) + self.eol_length
    end
    self.computed.sum_index = target_line
end

function MirrorTextModel:_get_prefix_sum(line)
    self:_compute_prefix_sum(line)
    return self.computed.sum_prefix[line + 1 - 1] or 0
end

---@param line integer 0-based
---@return string
function MirrorTextModel:line_at(line)
    return self.lines[line + 1]
end

function MirrorTextModel:line_count()
    return #self.lines
end

---@param vim_position FittenCode.Position
---@return lsp.Position
function MirrorTextModel:to_lsp_position(vim_position)
    local row = vim_position.row
    local pi = self:_get_layout(row)
    local col = Unicode.byte_to_utfindex_by_layout(pi, 'utf-16', vim_position.col + 1) - 1
    return { line = row, character = col }
end

---@param lsp_position lsp.Position
---@return FittenCode.Position
function MirrorTextModel:to_vim_position(lsp_position)
    local row = lsp_position.line
    local pi = self:_get_layout(row)
    local col = Unicode.utf_to_byteindex_by_layout(pi, 'utf-16', lsp_position.character + 1) - 1
    return Position.of(row, col)
end

---@param position lsp.Position
---@return lsp.Position
function MirrorTextModel:_validate_position(position)
    if #self.lines == 0 then
        return { line = 0, character = 0 }
    end
    local line, character = position.line, position.character
    if line < 0 then
        line = 0
        character = 0
    elseif line >= #self.lines then
        line = #self.lines - 1
        character = self:_get_u16_index(line)
    else
        local max_character = self:_get_u16_index(line)
        if character < 0 then
            character = 0
        elseif character > max_character then
            character = max_character
        end
    end
    return { line = line, character = character }
end

function MirrorTextModel:_validate_offset(offset)
    if offset < 0 then
        return 0
    elseif offset >= self:_get_prefix_sum(#self.lines - 1) then
        return self:_get_prefix_sum(#self.lines - 1)
    end
    return offset
end

---@param offset integer
---@return lsp.Position
function MirrorTextModel:position_at(offset)
    offset = self:_validate_offset(offset)
    local low = 0
    local high = #self.lines - 1
    local mid = 0
    local mid_stop = 0
    local mid_start = 0
    while low < high do
        mid = low + (high - low + 1) / 2
        mid_stop = self:_get_prefix_sum(mid)
        mid_start = mid_stop - self:_get_u16_index(mid)
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
    local line_length = self:_get_u16_index(index)
    return { line = index, character = math.min(line_length, remainder) }
end

-- Converts the position to a zero-based offset.
---@param position lsp.Position
---@return integer
function MirrorTextModel:offset_at(position)
    position = self:_validate_position(position)
    assert(position.line >= self.computed.u16_line)
    return self:_get_prefix_sum(position.line - 1) + position.character
end

---@param line integer
---@return FittenCode.Unicode.MultiEncodingStringLayout
function MirrorTextModel:_get_layout(line)
    if not self.computed.layouts[line + 1] then
        self.computed.layouts[line + 1] = Unicode.multi_encoding_layout(self.lines[line + 1])
    end
    return self.computed.layouts[line + 1]
end

---@param range? lsp.Range
---@return string
function MirrorTextModel:get_text(range)
    if not range then
        if not self.computed.full_text then
            self.computed.full_text = table.concat(self.lines, self.eol)
        end
        return self.computed.full_text
    end
    local result_lines = {}
    -- part 1
    local start_pi = self:_get_layout(range.start.line)
    local start_byte_index = Unicode.utf_to_byteindex_by_layout(start_pi, 'utf-16', range.start.character + 1) - 1
    local remaning = self:line_at(range.start.line):sub(start_byte_index)
    result_lines[#result_lines + 1] = remaning
    -- part 2
    for i = range.start.line + 1, range['end'].line - 1 do
        result_lines[#result_lines + 1] = self.lines[i + 1]
    end
    -- part 3
    local end_pi = self:_get_layout(range['end'].line)
    local end_byte_index = Unicode.utf_to_byteindex_by_layout(end_pi, 'utf-16', range['end'].character + 1) - 1
    end_byte_index = end_byte_index - 1
    if end_byte_index ~= -1 then
        remaning = self:line_at(range['end'].line):sub(1, end_byte_index)
        result_lines[#result_lines + 1] = remaning
    end
    return table.concat(result_lines, self.eol)
end

---@param encoding lsp.PositionEncodingKind
---@param line integer
---@param character integer
---@return integer, integer
function MirrorTextModel:round_start(encoding, line, character)
    local pi = self:_get_layout(line)
    local start = Unicode.round_start_by_layout(pi, encoding, character + 1) - 1
    return line, start
end

---@param encoding lsp.PositionEncodingKind
---@param line integer
---@param character integer
---@return integer, integer
function MirrorTextModel:round_end(encoding, line, character)
    local pi = self:_get_layout(line)
    local end_ = Unicode.round_end_by_layout(pi, encoding, character + 1) - 1
    return line, end_
end

return MirrorTextModel
