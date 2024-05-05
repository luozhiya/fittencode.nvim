local Libcurl = require('fittencode.rest.backend.libcurl.api.libcurl')

local M = {}

function M.setup()
  Libcurl.global_init()
end

return M
