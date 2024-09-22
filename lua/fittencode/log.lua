local Config = require('fittencode.config')

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

local first_log = true

local LogPath = vim.fn.stdpath('log') .. '/fittencode' .. '/fittencode.log'
local MaxSize = 10 * 1024 * 1024 -- 10MB

local function level_name(level)
    for k, v in pairs(levels) do
        if v == level then
            return k
        end
    end
    return 'UNKNOWN'
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
        nvim = nvim or 'UNKNOWN',
        buildtype = buildtype or 'UNKNOWN',
        luajit = luajit or 'UNKNOWN',
    }
end

local function write_first_log(f)
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

local function log_file(msg)
    local f = assert(io.open(LogPath, 'a'))
    if first_log then
        write_first_log(f)
        first_log = false
    end
    f:write(string.format('%s\n', msg))
    f:close()
end

local function expand_msg(msg, ...)
    msg = msg or ''
    local count = 0
    msg, count = msg:gsub('{}', '%%s')
    if count == 0 and select('#', ...) == 0 then
        return msg
    end
    local args = vim.tbl_map(vim.inspect, { ... })
    for i = #args + 1, count do
        args[i] = vim.inspect(nil)
    end
    msg = string.format(msg, unpack(args))
    return msg
end

function M.log(level, msg, ...)
    if level >= Config.log.level and Config.log.level ~= levels.OFF then
        msg = expand_msg(msg, ...)
        local ms = string.format('%03d', math.floor((vim.uv.hrtime() / 1e6) % 1000))
        local timestamp = os.date('%Y-%m-%d %H:%M:%S') .. '.' .. ms
        local tag = string.format('[%-5s %s] ', level_name(level), timestamp)
        msg = tag .. (msg or '')
        log_file(msg)
    end
end

function M.notify(level, msg, ...)
    msg = expand_msg(msg, ...)
    vim.schedule(function()
        vim.notify(msg, level, { title = 'Fittencode' })
    end)
    M.log(level, msg)
end

function M.setup()
    local log_dir = vim.fn.fnamemodify(LogPath, ':h')
    if vim.fn.mkdir(log_dir, 'p') ~= 1 then
        vim.api.nvim_err_writeln('Failed to create log directory: ' .. log_dir)
    end

    local log_size = vim.fn.getfsize(LogPath)
    if log_size > 0 and log_size > MaxSize then
        if vim.fn.delete(LogPath) ~= 0 then
            vim.api.nvim_err_writeln('Failed to delete log file: ' .. LogPath)
        end
    end
end

function M.set_level(level)
    Config.log.level = level
end

for k, v in pairs(levels) do
    M[k:lower()] = function(...) M.log(v, ...) end
    M['notify_' .. k:lower()] = function(...) M.notify(v, ...) end
end

return M
