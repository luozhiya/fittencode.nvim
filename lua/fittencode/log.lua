local Config = require('fittencode.config')
local Format = require('fittencode.format')

---@class FittenCode.Log
---@field error function
---@field warn function
---@field info function
---@field debug function
---@field trace function
---@field notify_error function
---@field notify_warn function
---@field notify_info function
---@field notify_debug function
---@field notify_trace function
---@field dev_error function
---@field dev_warn function
---@field dev_info function
---@field dev_debug function
---@field dev_trace function

---@class FittenCode.Log
local M = {}

-- See `help vim.log.levels`
-- Refs: `neovim/runtime/lua/vim/_editor.lua`
--[[
  ```lua
  vim.log = {
    levels = {
      TRACE = 0,
      DEBUG = 1,
      INFO = 2,
      WARN = 3,
      ERROR = 4,
      OFF = 5,
    },
  }
  ```
]]
local levels = vim.deepcopy(vim.log.levels)

local logfile = vim.fn.stdpath('log') .. '/fittencode' .. '/fittencode.log'
local max_size = 2 * 1024 * 1024 -- 2MB

local preface = true

local names = { 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR' }

---@param level number
---@return string
local function level_name(level)
    return names[level + 1] or '----'
end

local function neovim_version()
    local version = vim.fn.execute('version')
    assert(version)

    local function find_part(offset, part)
        local start = version:find(part, offset)
        if not start then
            return nil
        end
        local end_ = version:find('\n', start + #part) or #version
        return start + #part, end_, version:sub(start + #part, end_ - 1)
    end

    local nvim_start, nvim_end, nvim = find_part(0, 'NVIM ')
    local buildtype_start, buildtype_end, buildtype = find_part(nvim_end, 'Build type: ')
    local luajit_start, luajit_end, luajit = find_part(buildtype_end, 'LuaJIT ')

    return {
        nvim = nvim,
        buildtype = buildtype,
        luajit = luajit,
    }
end

local function async_log(msg)
    vim.schedule(function()
        local content = {}
        if preface then
            preface = false
            vim.fn.mkdir(vim.fn.fnamemodify(logfile, ':h'), 'p')
            if Config.log.developer_mode or vim.fn.getfsize(logfile) > max_size then
                vim.fn.delete(logfile)
            end
            local edge = string.rep('=', 80)
            local info = {
                { 'Verbose logging started', os.date('%Y-%m-%d %H:%M:%S') },
                { 'Log level',               level_name(Config.log.level) },
                { 'Calling process',         vim.uv.exepath() },
                { 'Neovim',                  vim.inspect(neovim_version()) },
                { 'Process ID',              vim.uv.os_getpid() },
                { 'Parent process ID',       vim.uv.os_getppid() },
                { 'OS',                      vim.inspect(vim.uv.os_uname()) }
            }
            content[#content + 1] = edge
            for _, entry in ipairs(info) do
                content[#content + 1] = string.format('%s: %s', entry[1], entry[2])
            end
            content[#content + 1] = edge
        end
        local f = assert(io.open(logfile, 'a'))
        content[#content + 1] = string.format('%s', msg)
        f:write(table.concat(content, '\n') .. '\n')
        f:close()
    end)
end

local function log(level, msg, ...)
    if level >= Config.log.level and Config.log.level ~= levels.OFF then
        msg = Format.safe_format(msg, ...)
        local ms = string.format('%03d', math.floor((vim.uv.hrtime() / 1e6) % 1000))
        local timestamp = os.date('%Y-%m-%d %H:%M:%S') .. '.' .. ms
        local tag = string.format('[%-5s %s] ', level_name(level), timestamp)
        msg = tag .. (msg or '')
        async_log(msg)
    end
end

local function notify(level, msg, ...)
    msg = Format.safe_format(msg, ...)
    vim.schedule(function()
        vim.notify(msg, level, { title = 'FittenCode' })
    end)
    log(level, msg)
end

function M.set_level(level)
    Config.log.level = level
end

local developer = 'FittenDocument-FT-ozlpsknq83720108429'

for level, name in pairs(names) do
    M[name:lower()] = function(...) log(levels[name], ...) end
    M['notify_' .. name:lower()] = function(...) notify(levels[name], ...) end
    M['dev_' .. name:lower()] = function(...)
        if Config.document_file == developer then
            log(levels[name], ...)
        end
    end
end

return M
