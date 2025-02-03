local M = {}

-- 格式注册表结构示例
local registry = {
    ['gz'] = {
        mime = 'application/gzip',
        magic = '\x1F\x8B\x08',
        engines = {
            compress = { 'cli.gzip', 'zlib' },
            decompress = { 'cli.gzip', 'zlib' }
        },
        default_engine = 'cli.gzip',
        args_template = {
            compress = { '-c', '-${level}' }, -- 支持变量插值
            decompress = { '-d', '-c' }
        }
    },
    ['tar.gz'] = {
        composite = { 'tar', 'gz' },
        engines = {
            compress = { 'composite.tar_gz' },
            decompress = { 'composite.tar_gz' }
        }
    }
}

function M.detect_format(input, is_file)
    if is_file then
        -- 通过文件头检测
        local fd = io.open(input, 'rb')
        local header = fd:read(3)
        fd:close()

        for format, spec in pairs(registry) do
            if spec.magic and header == spec.magic then
                return format
            end
        end

        -- 通过扩展名检测
        local ext = input:match('%.([^%.]+)$')
        return ext and registry[ext] and ext
    end
    return nil
end

function M.get_format_config(format)
    return vim.deepcopy(registry[format] or {})
end

function M.register_format(name, config)
    registry[name] = config
end

return M
