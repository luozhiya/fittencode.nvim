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

-- 常量定义
local LOG_LEVELS = vim.deepcopy(vim.log.levels)
local LOG_LEVEL_NAMES = { 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR' }
local LOG_FILE = vim.fn.stdpath('log') .. '/fittencode/fittencode.log'
local MAX_LOG_SIZE = 2 * 1024 * 1024 -- 2MB
local DEVELOPER_DOCUMENT = 'FittenDocument-FT-ozlpsknq83720108429'

-- 状态变量
local needs_preface = true

--[[ 辅助函数 ]]
--
local function get_level_name(level)
    return LOG_LEVEL_NAMES[level + 1] or 'UNKNOWN'
end

local function format_timestamp()
    local ms = string.format('%03d', math.floor((vim.uv.hrtime() / 1e6) % 1000))
    return os.date('%Y-%m-%d %H:%M:%S') .. '.' .. ms
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
        string.format('Neovim version: %s', collect_neovim_info().nvim),
        string.format('Process ID: %d', vim.uv.os_getpid()),
        string.format('OS: %s', vim.inspect(vim.uv.os_uname())),
        edge
    }
    return table.concat(header, '\n')
end

local function ensure_log_directory()
    local log_dir = vim.fn.fnamemodify(LOG_FILE, ':h')
    if vim.fn.isdirectory(log_dir) == 0 then
        vim.fn.mkdir(log_dir, 'p')
    end
end

local function rotate_log_if_needed()
    if Config.log.developer_mode or vim.fn.getfsize(LOG_FILE) > MAX_LOG_SIZE then
        vim.fn.delete(LOG_FILE)
    end
end

--[[ 核心日志功能 ]]
--
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

    vim.schedule(function()
        -- 初始化检查
        if needs_preface then
            ensure_log_directory()
            rotate_log_if_needed()
            write_to_log(prepare_log_header())
            needs_preface = false
        end

        -- 格式化日志条目
        local log_entry = string.format('[%-5s %s] %s',
            get_level_name(level),
            format_timestamp(),
            message
        )

        write_to_log(log_entry)
    end)
end

--[[ 公共接口 ]]
--
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

return M
