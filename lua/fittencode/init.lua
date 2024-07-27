local M = {}

---@param opts? FittenCodeOptions
function M.setup(opts)
  if vim.fn.has('nvim-0.8.0') == 0 then
    local msg = 'fittencode.nvim requires Neovim >= 0.8.0.'
    vim.api.nvim_err_writeln(msg)
    return
  end

  local Config = require('fittencode.config')
  Config.setup(opts)

  require('fittencode.log').setup()
  require('fittencode.rest.manager').setup()
  local Sessions = require('fittencode.sessions')
  Sessions.setup()
  require('fittencode.engines').setup()
  require('fittencode.actions').setup()
  require('fittencode.prompt_providers').setup()
  require('fittencode.color').setup()
  require('fittencode.commands').setup()
  Sessions.load_last_session()
end

setmetatable(M, {
  __index = function(_, k)
    return function(...)
      return require('fittencode.api').api[k](...)
    end
  end,
})

return M
