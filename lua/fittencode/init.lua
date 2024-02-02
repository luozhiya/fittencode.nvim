local Sessions = require('fittencode.sessions')
local Bindings = require('fittencode.bindings')

local M = {}

M.config = {}

function M.setup(cfg)
  Sessions.read_local_api_key()
  Bindings.setup_autocmds()
  Bindings.setup_commands()
  Bindings.setup_keymaps()
end

return M
