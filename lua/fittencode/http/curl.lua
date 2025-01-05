local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')
local Config = require('fittencode.config')
local Process = require('fittencode.process')

---@class FittenCode.HTTP.CURL.Request : FittenCode.HTTP.Request

local Impl = {}

local curl_meta = {
    cmd = 'curl',
    args = {
        '-s',
        '--show-error',
        '--no-buffer',
    },
    code = 0
}

---@param options FittenCode.HTTP.CURL.Request
local function extend_args(curl, args, options)
    if type(options.timeout) == 'number' then
        args[#args + 1] = '--connect-timeout'
        args[#args + 1] = options.timeout
    end
    for k, v in pairs(options.headers or {}) do
        args[#args + 1] = '-H'
        if Fn.is_windows() then
            args[#args + 1] = '"' .. k .. ': ' .. v .. '"'
        else
            args[#args + 1] = k .. ': ' .. v
        end
    end
    vim.list_extend(curl.args, args)
end

---@param url string
---@param options FittenCode.HTTP.CURL.Request
function Impl.get(url, options)
    local curl = vim.deepcopy(curl_meta)
    if #Config.http.curl.command ~= 0 then
        curl.cmd = Config.http.curl.command
    end
    local args = {
        url,
    }
    extend_args(curl, args, options)
    ---@diagnostic disable-next-line: param-type-mismatch
    Process.spawn(curl, options)
end

---@param options FittenCode.HTTP.CURL.Request
---@return boolean
local function is_gzip(options)
    return options.headers ~= nil and options.headers['Content-Encoding'] == 'gzip'
end

---@param url string
---@param options FittenCode.HTTP.CURL.Request
function Impl.post(url, options)
    local curl = vim.deepcopy(curl_meta)
    if #Config.http.curl.command ~= 0 then
        curl.cmd = Config.http.curl.command
    end
    local args = {
        url,
        '-X',
        'POST',
    }
    local tempname = vim.fn.tempname()
    local f = assert(vim.uv.fs_open(tempname, 'w', 438))
    vim.uv.fs_write(f, options.body)
    vim.uv.fs_close(f)
    args[#args + 1] = is_gzip(options) and '--data-binary' or '--data'
    args[#args + 1] = '@' .. tempname
    extend_args(curl, args, options)
    local spawn_options = Fn.tbl_keep_events(options, {
        on_exit = function()
            Fn.schedule_call(options.on_exit)
            vim.uv.fs_unlink(tempname)
        end,
    })
    ---@diagnostic disable-next-line: param-type-mismatch
    Process.spawn(curl, spawn_options)
end

---@param url string
---@param options? FittenCode.HTTP.Request
local function fetch(url, options)
    Log.debug('Fetching URL: ' .. url)
    local function _()
        options = options or {}
        local aborted = false
        local abortable_options = vim.tbl_deep_extend('force', options, {
            on_create = vim.schedule_wrap(function(data)
                ---@type uv_process_t?
                local process = data.process
                ---@type FittenCode.HTTP.RequestHandle
                local handle = {
                    abort = function()
                        if not aborted then
                            pcall(function()
                                if process then
                                    vim.uv.process_kill(process)
                                end
                            end)
                            aborted = true
                        end
                    end,
                    is_active = function()
                        if process then
                            return vim.uv.is_active(process)
                        end
                        return false
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
        Fn.schedule_call(Impl[string.lower(options.method)], url, abortable_options)
    end
    return _()
end

return {
    fetch = fetch,
}
