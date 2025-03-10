local Config = require('fittencode.config')
local Format = require('fittencode.functional.format')
local Path = require('fittencode.functional.path')
local Stateful = require('fittencode.stateful')

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

-- 常量定义
local LOG_LEVELS = vim.deepcopy(vim.log.levels)
local LOG_LEVEL_NAMES = { 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR' }
local LOG_FILE = Path.join(vim.fn.stdpath('log'), 'fittencode', 'fittencode.log')
local MAX_LOG_SIZE = 2 * 1024 * 1024 -- 2MB
local DEVELOPER_DOCUMENT = 'FittenDocument-FT-ozlpsknq83720108429'

local needs_preface = true

local function get_level_name(level)
    return LOG_LEVEL_NAMES[level + 1] or 'UNKNOWN'
end

local function get_ns_time()
    local sec, usec = vim.uv.gettimeofday()
    if sec == nil then
        usec = 0
    end
    return usec * 1000
end

local function format_timestamp()
    local ns = string.format('%09d', get_ns_time())
    local date = os.date('%Y-%m-%dT%H:%M:%S')
    -- +0800 -> +08:00
    local timezone = tostring(os.date('%z'))
    timezone = timezone:sub(1, 3) .. ':' .. timezone:sub(4, 5)
    return date .. '.' .. ns .. timezone
end

local function collect_neovim_info()
    local version_info = vim.fn.execute('version')
    local info = {
        nvim = version_info:match('NVIM v(%d+%.%d+%.%d+)'),
        build_type = version_info:match('Build type: (%S+)'),
        luajit = version_info:match('LuaJIT (%d+%.%d+%.%d+)'),
        os_info = vim.uv.os_uname(),
    }
    return info
end

local function prepare_log_header()
    local edge = string.rep('=', 80)
    local header = {
        edge,
        string.format('Verbose logging started: %s', os.date('%Y-%m-%d %H:%M:%S')),
        string.format('Log level: %s', get_level_name(Config.log.level)),
        string.format('Calling process: %s', vim.uv.exepath()),
        string.format('Neovim version: %s', collect_neovim_info().nvim),
        string.format('Process ID: %d', vim.uv.os_getpid()),
        string.format('Parent process ID: %d', vim.uv.os_getppid()),
        string.format('OS name: %s', vim.inspect(vim.uv.os_uname())),
        string.format('GUI running: %s', vim.fn.has('gui_running')),
        string.format('WSL running: %s', vim.fn.has('wsl')),
    }
    if Config.log.env then
        header[#header + 1] = string.format('Environment: %s', vim.inspect(vim.uv.os_environ()))
    end
    header[#header + 1] = edge
    return table.concat(header, '\n')
end

local function ensure_log_directory()
    local log_dir = vim.fn.fnamemodify(LOG_FILE, ':h')
    if vim.fn.isdirectory(log_dir) == 0 then
        vim.fn.mkdir(log_dir, 'p')
    end
end

local function rotate_log_if_needed()
    if Config.developer_mode or vim.fn.getfsize(LOG_FILE) > MAX_LOG_SIZE then
        vim.fn.delete(LOG_FILE)
    end
end

local function write_to_log(content)
    local ok, err = pcall(function()
        local file = io.open(LOG_FILE, 'a')
        if not file then return end

        file:write(content .. '\n')
        file:close()
    end)

    if not ok and Config.log.enable_notifications then
        vim.notify('Log write failed: ' .. err, LOG_LEVELS.ERROR)
    end
end

local function async_log(level, message)
    if level < Config.log.level or Config.log.level == LOG_LEVELS.OFF then
        return
    end

    -- 获取当前文件名
    local info = debug.getinfo(3, 'Snl')
    local file_name = info.source:sub(2) -- 去掉 '@' 符号
    -- 找到 "lua/fittencode/" 的起始位置并截取
    local prefix = 'lua/fittencode/'
    local start_pos = file_name:find(prefix, 1, true)
    if start_pos then
        file_name = file_name:sub(start_pos + #prefix)
    end
    local line_number = info.currentline

    vim.schedule(function()
        -- 初始化检查
        if needs_preface then
            ensure_log_directory()
            rotate_log_if_needed()
            write_to_log(prepare_log_header())
            needs_preface = false
        end

        -- 格式化日志条目
        local log_entry = string.format('[%s %s:%d %s] %s',
            format_timestamp(),
            file_name,
            line_number,
            get_level_name(level),
            message
        )

        write_to_log(log_entry)
    end)
end

function M.set_level(level)
    if type(level) == 'string' then
        level = LOG_LEVELS[level:upper()]
    end
    Config.log.level = level or LOG_LEVELS.INFO
end

function M.init()
    for _, level_name in ipairs(LOG_LEVEL_NAMES) do
        local level = LOG_LEVELS[level_name]
        local method_name = level_name:lower()

        -- 标准日志方法
        M[method_name] = function(msg, ...)
            async_log(level, Format.safe_format(msg, ...))
        end

        -- 通知方法
        M['notify_' .. method_name] = function(msg, ...)
            local formatted = Format.safe_format(msg, ...)
            vim.notify(formatted, level, { title = 'FittenCode' })
            async_log(level, formatted)
        end

        -- 开发者方法
        M['dev_' .. method_name] = function(msg, ...)
            if Config.document_file == DEVELOPER_DOCUMENT then
                async_log(level, Format.safe_format(msg, ...))
            end
        end
    end
end

function M.open_log_file()
    vim.cmd.edit(LOG_FILE)
end

function M.destroy()
    needs_preface = true
end

return Stateful.make_stateful(M)
