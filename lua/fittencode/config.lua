---@class fittencode.Config
local M = {}

local defaults = {}

local options = {}

---@param opts? fittencode.Config
function M.setup(opts)
  vim.api.nvim_create_user_command('FittenCode', function(input)
    require('fittencode.command').execute(input)
  end, {
    nargs = '*',
    complete = function(...)
      return require('fittencode.command').complete(...)
    end,
    desc = 'FittenCode',
  })
end

return setmetatable(M, {
  __index = function(_, key)
    return options[key]
  end,
})
