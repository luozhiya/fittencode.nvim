---@class FittenCode.TextDocument
local TextDocument = {}
TextDocument.__index = TextDocument

-- Creates a new TextDocument object. The buffer must be valid.
---@return FittenCode.TextDocument
function TextDocument:new(buf)
    assert(buf and vim.api.nvim_buf_is_valid(buf), 'Invalid buffer')
    local obj = {
        buf = buf,
    }
    setmetatable(obj, TextDocument)
    return obj
end

return TextDocument
