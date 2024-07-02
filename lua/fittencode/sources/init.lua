local Config = require('fittencode.config')
local Log = require('fittencode.log')

local M = {}

---@class SourceCompletionOptions
---@field enable boolean
---@field engine string

local builtins = {
  ['cmp'] = function()
    require('fittencode.sources.cmp').setup()
  end,
}

function M.is_available()
  if Config.options.completion_mode ~= 'source' then
    return false
  end
  if not Config.options.source_completion.enable then
    return false
  end
  local filetype = vim.bo.filetype
  if vim.tbl_contains(Config.options.disable_specific_inline_completion.suffixes, filetype) then
    return false
  end
  return true
end

local function make_engine(engine)
  if builtins[engine] then
    builtins[engine]()
  else
    Log.error('Invalid completion engine: {} ', engine)
  end
end

function M.setup()
  make_engine(Config.options.source_completion.engine)
end

return M
