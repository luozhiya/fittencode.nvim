---@class fittencode.api
local M = {}

---@param opts? fittencode.Config
function M.setup(opts)
  require('fittencode.config').setup(opts)
end

return setmetatable(M, {
  __index = function(_, key)
    return require('fittencode.api')[key]
  end,
})
