local ShadowTextModel = require('fittencode.fn.shadow_text_model')

---@class FittenCode.ShadowDocument
---@field buffer integer
---@field version integer
---@field lines string[]
local ShadowDocument = {}
ShadowDocument.__index = ShadowDocument

---@class FittenCode.ShadowDocument.InitializeOptions
---@field buffer integer

---@param options FittenCode.ShadowDocument.InitializeOptions
function ShadowDocument.new(options)
    assert(options)
    local self = setmetatable({}, ShadowDocument)
    self:_initialize(options)
    return self
end

---@param options FittenCode.ShadowDocument.InitializeOptions
function ShadowDocument:_initialize(options)
    assert(type(options.buffer) == 'number', 'buffer must be a number')
    assert(vim.api.nvim_buf_is_valid(options.buffer), 'buffer is not valid')
    self.buffer = options.buffer
    self.version = vim.api.nvim_buf_get_changedtick(self.buffer)
    self.lines = vim.api.nvim_buf_get_lines(self.buffer, 0, -1, false)
    self.model = ShadowTextModel.new({ lines = self.lines, eol = '\n' })
end

---@param row integer 0-based
function ShadowDocument:line_at(row)
    return self.model:line_at(row)
end

function ShadowDocument:line_count()
    return self.model:line_count()
end

---@param vim_position FittenCode.Position
---@return lsp.Position
function ShadowDocument:to_lsp_position(vim_position)
    return self.model:to_lsp_position(vim_position)
end

---@param lsp_position lsp.Position
---@return FittenCode.Position
function ShadowDocument:to_vim_position(lsp_position)
    return self.model:to_vim_position(lsp_position)
end

---@param offset integer
---@return lsp.Position
function ShadowDocument:position_at(offset)
    return self.model:position_at(offset)
end

-- Converts the position to a zero-based offset.
---@param position lsp.Position
---@return integer
function ShadowDocument:offset_at(position)
    return self.model:offset_at(position)
end

---@param range lsp.Range
---@return string
function ShadowDocument:get_text(range)
    return self.model:get_text(range)
end

return ShadowDocument
