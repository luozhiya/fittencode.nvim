package.cpath = require('fittencode.rest.backend.libcurl.api.cpath').cpath

local curlua = require 'libcurlua'

local M = {}

---@return number, string?
function M.global_init()
  return curlua.curlua_global_init()
end

return M
