local M = {}

local param_map = {
    gzip = {
        compress = {
            level = '-%d',
            fast = '--fast',
            best = '--best'
        },
        decompress = {
            keep = '-k'
        }
    },
    zip = {
        compress = {
            level = '-%d',
            encrypt = "-P '%s'"
        }
    }
}

function M.generate_args(tool, operation, opts)
    local mapping = param_map[tool][operation]
    local args = {}

    -- 处理通用参数
    if opts.level and mapping.level then
        table.insert(args, mapping.level:format(opts.level))
    end

    -- 处理工具特定参数
    if tool == 'gzip' and opts.fast then
        table.insert(args, mapping.fast)
    end

    -- 处理加密参数
    if opts.encryption and mapping.encrypt then
        table.insert(args, mapping.encrypt:format(opts.encryption.password))
    end

    return args
end

return M
