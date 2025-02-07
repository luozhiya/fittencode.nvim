local M = {}

local function validate_common(opts)
    -- 必须参数检查
    if not opts.input then
        return false, 'Missing required parameter: input'
    end

    -- 输入类型验证
    local valid_types = { 'data', 'file', 'directory' }
    if opts.input_type and not vim.tbl_contains(valid_types, opts.input_type) then
        return false, ('Invalid input_type: %s (valid: %s)'):format(
            opts.input_type,
            table.concat(valid_types, ', ')
        )
    end

    -- 输出路径合法性
    if opts.output_path then
        if opts.input_type == 'file' and vim.uv.fs_stat(opts.output_path) then
            return false, 'Output path already exists: ' .. opts.output_path
        end
    end
end

local function validate_compress(opts)
    -- 压缩级别检查
    if opts.level then
        if type(opts.level) ~= 'number' then
            return false, 'Compression level must be a number'
        end

        -- local engine = get_engine(opts.format)
        -- if engine.capabilities.compress.levels then
        --     local min, max = unpack(engine.capabilities.compress.levels)
        --     if opts.level < min or opts.level > max then
        --         return false, ("Level %d out of range (%d-%d)"):format(opts.level, min, max)
        --     end
        -- end
    end

    -- 加密参数检查
    if opts.encryption then
        if not opts.encryption.password then
            return false, 'Encryption requires password'
        end
        if opts.encryption.method and not vim.tbl_contains({ 'AES128', 'AES256' }, opts.encryption.method) then
            return false, 'Unsupported encryption method'
        end
    end
end

local function validate_decompress(opts)
    -- 解压文件存在性检查
    if opts.input_type == 'file' and not vim.uv.fs_stat(opts.input) then
        return false, 'Input file not found: ' .. opts.input
    end

    -- 输出目录可写性检查
    if opts.output_path then
        local dir = opts.output_path
        if vim.uv.fs_access(dir, 'w') then
            return false, 'Output directory not writable: ' .. dir
        end
    end
end

function M.validate(opts)
    local ok, err = validate_common(opts)
    if not ok then return false, err end

    if opts.operation == 'compress' then
        return validate_compress(opts)
    elseif opts.operation == 'decompress' then
        return validate_decompress(opts)
    end

    return false, 'Unknown operation: ' .. (opts.operation or 'nil')
end

return M
