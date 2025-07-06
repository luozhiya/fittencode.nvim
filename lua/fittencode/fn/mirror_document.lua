local MirrorTextModel = require('fittencode.fn.mirror_text_model')

---@class FittenCode.MirrorDocument
---@field buffer integer
---@field version integer
---@field lines string[]
local MirrorDocument = {}
MirrorDocument.__index = MirrorDocument

---@class FittenCode.MirrorDocument.InitializeOptions
---@field buffer integer

---@param options FittenCode.MirrorDocument.InitializeOptions
function MirrorDocument.new(options)
    assert(options)
    local self = setmetatable({}, MirrorDocument)
    self:_initialize(options)
    return self
end

---@param options FittenCode.MirrorDocument.InitializeOptions
function MirrorDocument:_initialize(options)
    assert(type(options.buffer) == 'number', 'buffer must be a number')
    assert(vim.api.nvim_buf_is_valid(options.buffer), 'buffer is not valid')
    self.buffer = options.buffer
    self.version = vim.api.nvim_buf_get_changedtick(self.buffer)
    self.lines = vim.api.nvim_buf_get_lines(self.buffer, 0, -1, false)
    self.model = MirrorTextModel.new({ lines = self.lines, eol = '\n' })
end

---@param row integer 0-based
function MirrorDocument:line_at(row)
    return self.model:line_at(row)
end

function MirrorDocument:line_count()
    return self.model:line_count()
end

---@param vim_position FittenCode.Position
---@return lsp.Position
function MirrorDocument:to_lsp_position(vim_position)
    return self.model:to_lsp_position(vim_position)
end

---@param lsp_position lsp.Position
---@return FittenCode.Position
function MirrorDocument:to_vim_position(lsp_position)
    return self.model:to_vim_position(lsp_position)
end

---@param offset integer
---@return lsp.Position
function MirrorDocument:position_at(offset)
    return self.model:position_at(offset)
end

-- Converts the position to a zero-based offset.
---@param position lsp.Position
---@return integer
function MirrorDocument:offset_at(position)
    return self.model:offset_at(position)
end

---@param range lsp.Range
---@return string
function MirrorDocument:get_text(range)
    return self.model:get_text(range)
end

return MirrorDocument
