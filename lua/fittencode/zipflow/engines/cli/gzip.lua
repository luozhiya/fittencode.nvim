local spawn = require('fittencode.process.spawn2')
local Promise = require('fittencode.concurrency.promise')

local M = {
    name = 'gzip',
    category = 'cli',
    priority = 80,
    features = {
        async = true,
        performance = 0.6
    },
    capabilities = {
        compress = {
            format = { 'gzip', 'gz' },
            input_types = { 'data', 'file' },
            output_types = { 'data', 'file' },
            levels = { 1, 9 },
            methods = { 'deflate' }
        },
        decompress = {
            format = { 'gzip', 'gz' },
            input_types = { 'data', 'file' },
            output_types = { 'data', 'file', 'directory' }
        }
    }
}

local function handle_data_input(input, opts)
    return Promise.new(function(resolve, reject)
        local args = { '-c', '--no-name' }
        if opts.level then
            table.insert(args, '-' .. opts.level)
        end

        local p = spawn('gzip', args, {
            stdio = {
                stdin = 'pipe',
                stdout = 'pipe',
                stderr = 'pipe'
            }
        })

        local output = {}
        local errors = {}

        p.stdin:write(input)
        p.stdin:shutdown()

        p.stdout:on('data', function(data)
            table.insert(output, data)
        end)

        p.stderr:on('data', function(data)
            table.insert(errors, data)
        end)

        p:on('exit', function(code)
            if code == 0 then
                resolve({
                    data = table.concat(output),
                    meta = {
                        original_size = #input,
                        compressed_size = #table.concat(output)
                    }
                })
            else
                reject({
                    code = 'GZIP_ERROR',
                    message = 'Compression failed: ' .. table.concat(errors),
                    exit_code = code
                })
            end
        end)
    end)
end

local function handle_file_input(input_path, opts)
    return Promise.new(function(resolve, reject)
        local output_path = opts.output_path or input_path .. '.gz'
        local args = { '-k', '--force' }

        if opts.level then
            table.insert(args, '-' .. opts.level)
        end

        table.insert(args, input_path)

        local p = spawn('gzip', args)

        p:on('exit', function(code)
            if code == 0 then
                resolve({
                    path = output_path,
                    meta = {
                        original_path = input_path,
                        compressed_path = output_path
                    }
                })
            else
                reject({
                    code = 'GZIP_FILE_ERROR',
                    message = ('Failed to compress file: %s'):format(input_path),
                    exit_code = code
                })
            end
        end)
    end)
end

local function handle_directory(input_dir, opts)
    return Promise.new(function(resolve, reject)
        local temp_tar = vim.uv.fs_mkstemp('zipflow_tar_XXXXXX') .. '.tar'
        local tar_args = {
            '-cf', temp_tar,
            '-C', input_dir,
            '.'
        }

        spawn.spawn('tar', tar_args)
            :on('exit', function(code)
                if code ~= 0 then
                    return reject('Failed to create tar archive')
                end

                handle_file_input(temp_tar, opts)
                    :forward(function(result)
                        vim.uv.fs_unlink(temp_tar)
                        resolve({
                            path = result.path,
                            meta = {
                                original_dir = input_dir,
                                temp_files = { temp_tar }
                            }
                        })
                    end)
                    :catch(function(err)
                        vim.uv.fs_unlink(temp_tar)
                        reject(err)
                    end)
            end)
    end)
end

function M.compress(input, opts)
    return Promise.new(function(resolve, reject)
        local input_type = opts.input_type or 'data'

        -- 数据输入
        if input_type == 'data' then
            return handle_data_input(input, opts)
                :forward(resolve)
                :catch(reject)
        end

        -- 文件系统输入需要检查路径有效性
        local ok, stat = pcall(vim.uv.fs_stat, input)
        if not ok then
            return reject({
                code = 'INVALID_INPUT',
                message = ('Path does not exist: %s'):format(input)
            })
        end

        -- 目录处理
        if stat.type == 'directory' then
            if not M.capabilities.compress.input_types:includes('directory') then
                return reject('Directory compression not supported')
            end
            return handle_directory(input, opts)
                :forward(resolve)
                :catch(reject)
        end

        -- 文件处理
        if stat.type == 'file' then
            return handle_file_input(input, opts)
                :forward(resolve)
                :catch(reject)
        end

        reject({
            code = 'UNSUPPORTED_TYPE',
            message = ('Unsupported input type: %s'):format(stat.type)
        })
    end)
end

-- Decompress实现类似结构，此处省略

return M
