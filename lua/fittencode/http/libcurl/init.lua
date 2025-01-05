package.cpath = package.cpath .. ';' .. require('cpath')

local CC = require('libcurl')
local Fn = require('fittencode.fn')

CC.global_init()

local M = {}

---@param url string
---@param options? FittenCode.HTTP.Request
function M.fetch(url, options)
    options = options or {}
    local function _()
        local aborted = false
        local abortable_options = vim.tbl_deep_extend('force', options, {
            on_create = vim.schedule_wrap(function(curlobject)
                local handle = {
                    abort = function()
                        if not aborted then
                            pcall(CC.abort, curlobject)
                            aborted = true
                        end
                    end,
                    is_active = function()
                        local _, is_active = pcall(CC.is_active, curlobject)
                        if not _ then
                            return false
                        end
                        return is_active
                    end
                }
                Fn.schedule_call(options.on_create, handle)
            end),
            on_stream = vim.schedule_wrap(function(chunk)
                if aborted then return end
                Fn.schedule_call(options.on_stream, chunk)
            end),
            on_once = vim.schedule_wrap(function(data)
                if aborted then return end
                Fn.schedule_call(options.on_once, data)
            end),
            on_error = vim.schedule_wrap(function(data)
                Fn.schedule_call(options.on_error, data)
            end),
            on_exit = vim.schedule_wrap(function(data)
                Fn.schedule_call(options.on_exit, data)
            end),
        })
        Fn.schedule_call(function()
            if not pcall(CC.fetch, url, abortable_options) then
                Fn.schedule_call(options.on_error)
            end
        end)
    end
    return _()
end

return M
