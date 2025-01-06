local Config = require('fittencode.config')
local Fn = require('fittencode.fn')

-- Simple HTTP client
local M = {}

-- The Fetch API provides an interface for fetching resources
---@param url string
---@param options? FittenCode.HTTP.Request
function M.fetch(url, options)
    local fetch
    if Config.http.backend == 'libcurl' then
        fetch = require('fittencode.http.libcurl').fetch
    else
        fetch = require('fittencode.http.curl').fetch
    end
    assert(fetch)
    fetch(url, options)
end

return M
