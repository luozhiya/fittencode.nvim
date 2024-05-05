package.cpath = require('fittencode.rest.backend.libcurl.api.cpath').cpath

local So = require 'libcurlua'

local M = {}

---@return number, string?
function M.global_init()
  return So.curlua_global_init()
end

---@return number, string?
function M.global_cleanup()
  return So.curlua_global_cleanup()
end

function M.easy_init()
  return So.curlua_easy_init()
end

function M.easy_cleanup(CURL)
  return So.curlua_easy_cleanup(CURL)
end

function M.easy_setopt(CURL, option, value)
  return So.curlua_easy_setopt(CURL, option, value)
end

function M.easy_perform(CURL)
  return So.curlua_easy_perform(CURL)
end

return M
