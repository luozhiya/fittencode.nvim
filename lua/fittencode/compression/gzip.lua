local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Promise = require('fittencode.promise')
local Config = require('fittencode.config')
local Process = require('fittencode.process')

local M = {}

local gzip_meta = {
    cmd = 'gzip',
    args = {
        '--no-name',
        '--force',
        '--quiet'
    },
    code = 0
}

function M.is_supported(format)
    return format == 'gzip'
end

---@param format string
---@param input string
---@param options FittenCode.Compression.CompressOptions
function M.compress(format, input, options)
    if not M.is_supported(format) then
        Log.error('Unsupported format: {}', format)
        Fn.schedule_call(options.on_error)
        return
    end

    local gzip = vim.deepcopy(gzip_meta)
    if #Config.compress.gzip.command ~= 0 then
        gzip.cmd = Config.compress.gzip.command
    end

    local tempname = vim.fn.tempname()
    local fo = assert(vim.uv.fs_open(tempname, 'w', 438))
    vim.uv.fs_write(fo, input)
    vim.uv.fs_close(fo)

    gzip.args[#gzip.args + 1] = tempname

    ---@type FittenCode.Process.SpawnOptions
    local spawn_options = Fn.tbl_keep_events(options, {
        on_once = vim.schedule_wrap(function()
            local gz = tempname .. '.gz'
            if vim.fn.filereadable(gz) == 1 then
                local fw = assert(vim.uv.fs_open(gz, 'r', 438))
                local content = vim.uv.fs_read(fw, -1)
                vim.uv.fs_close(fw)
                vim.uv.fs_unlink(gz)
                Fn.schedule_call(options.on_once, content)
            else
                Fn.schedule_call(options.on_error)
            end
        end),
    })
    Process.spawn(gzip, spawn_options)
end

return M
