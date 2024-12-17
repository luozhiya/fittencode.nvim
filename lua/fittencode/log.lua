local Config = require('fittencode.config')
local Fn = require('fittencode.fn')

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

local log_path = vim.fn.stdpath('log') .. '/fittencode' .. '/fittencode.log'
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

local function write_preface(f)
    if not preface then
        return
    end
    preface = false

    local edge = string.rep('=', 80) .. '\n'
    f:write(edge)

    local info = {
        { 'Verbose logging started', os.date('%Y-%m-%d %H:%M:%S') },
        { 'Log level',               level_name(Config.log.level) },
        { 'Calling process',         vim.uv.exepath() },
        { 'Neovim',                  vim.inspect(neovim_version()) },
        { 'Process ID',              vim.uv.os_getpid() },
        { 'Parent process ID',       vim.uv.os_getppid() },
        { 'OS',                      vim.inspect(vim.uv.os_uname()) }
    }

    for _, entry in ipairs(info) do
        f:write(string.format('%s: %s\n', entry[1], entry[2]))
    end
    f:write(edge)
end

local function log(level, msg, ...)
    if level >= Config.log.level and Config.log.level ~= levels.OFF then
        if preface then
            vim.fn.mkdir(vim.fn.fnamemodify(log_path, ':h'), 'p')
            if vim.fn.getfsize(log_path) > max_size then
                vim.fn.delete(log_path)
            end
        end
        msg = Fn.expand_braces(msg, ...)
        local ms = string.format('%03d', math.floor((vim.uv.hrtime() / 1e6) % 1000))
        local timestamp = os.date('%Y-%m-%d %H:%M:%S') .. '.' .. ms
        local tag = string.format('[%-5s %s] ', level_name(level), timestamp)
        msg = tag .. (msg or '')
        local f = assert(io.open(log_path, 'a'))
        write_preface(f)
        f:write(string.format('%s\n', msg))
        f:close()
    end
end

local function notify(level, msg, ...)
    msg = Fn.expand_braces(msg, ...)
    vim.schedule(function()
        vim.notify(msg, level, { title = 'FittenCode' })
    end)
    log(level, msg)
end

function M.set_level(level)
    Config.log.level = level
end

for level, name in pairs(names) do
    M[name:lower()] = function(...) log(levels[name], ...) end
    M['notify_' .. name:lower()] = function(...) notify(levels[name], ...) end
end

-- remove log_path
if vim.fn.filereadable(log_path) then
    vim.fn.delete(log_path)
end

return M
