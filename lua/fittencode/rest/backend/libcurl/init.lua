local fn = vim.fn

local Base = require('fittencode.base')
local FS = require('fittencode.fs')
local Rest = require('fittencode.rest.rest')
local Log = require('fittencode.log')
local Process = require('fittencode.concurrency.process')
local Promise = require('fittencode.concurrency.promise')
local Libcurl = require('fittencode.rest.backend.libcurl.api.libcurl')

local schedule = Base.schedule

---@class RestLibcurlBackend : Rest
local M = Rest:new('RestLibcurlBackend')

function M:authorize(url, token, on_success, on_error)
end

function M:post(url, data, on_success, on_error)
end

return M

