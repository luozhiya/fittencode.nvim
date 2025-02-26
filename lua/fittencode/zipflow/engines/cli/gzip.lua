local Process = require('fittencode.vim.promisify.uv.spawn_new')
local Promise = require('fittencode.concurrency.promise')

local M = {
    name = 'gzip',
    category = 'cli',
    priority = 80,
    performance = {
        speed = 0.6,
        compression_ratio = 0.5
    },
    async = true,
    capabilities = {
        compress = {
            format = { 'gzip', 'gz' },
            input_types = { 'data', 'file' },
            levels = { 1, 9 },
            methods = { 'deflate' }
        },
        decompress = {
            format = { 'gzip', 'gz' },
            input_types = { 'data', 'file' },
        }
    }
}

local function handle_data_input(input, opts)
    return Promise.new(function(resolve, reject)
        local args = { '-c', '--no-name' }
        if opts.level then
            table.insert(args, '-' .. opts.level)
        end

        local p = Process.new('gzip', args, {
            stdin = input,
        })

        local output = {}
        local errors = {}

        p:on('stdout', function(data)
            table.insert(output, data)
        end)

        p:on('stderr', function(data)
            table.insert(errors, data)
        end)

        p:on('error', reject)

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

        p:async()
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

        local p = Process.spawn('gzip', args)

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

function M.compress(input, opts)
    return Promise.new(function(resolve, reject)
        -- 格式检查
        local format = opts.format
        if not vim.tbl_contains(M.capabilities.compress.format, format) then
            reject({
                code = 'UNSUPPORTED_FORMAT',
                message = ('Unsupported compression format: %s'):format(format)
            })
        end

        -- 数据输入
        local input_type = opts.input_type
        if input_type == 'data' then
            return handle_data_input(input, opts)
                :forward(resolve)
                :catch(reject)
        end

        -- 目录处理
        if input_type == 'directory' then
            return reject('Directory compression not supported')
        end

        -- 文件处理
        if input_type == 'file' then
            return handle_file_input(input, opts)
                :forward(resolve)
                :catch(reject)
        end

        reject({
            code = 'UNSUPPORTED_TYPE',
            message = ('Unsupported input type: %s'):format(input_type)
        })
    end)
end

local function decompress_data(input, opts)
    return Promise.new(function(resolve, reject)
        local args = { '-c', '-d' }
        local p = Process.spawn('gzip', args, {
            stdin = input
        })

        local output = {}
        local errors = {}

        p:on('stdout', function(data)
            table.insert(output, data)
        end)

        p:on('stderr', function(data)
            table.insert(errors, data)
        end)

        p:on('error', reject)

        p:on('exit', function(code)
            if code == 0 then
                resolve({
                    data = table.concat(output),
                    meta = {
                        compressed_size = #input,
                        original_size = #table.concat(output)
                    }
                })
            else
                reject({
                    code = 'GUNZIP_ERROR',
                    message = 'Decompression failed: ' .. table.concat(errors),
                    exit_code = code
                })
            end
        end)
    end)
end

local function decompress_file(input_path, opts)
    return Promise.new(function(resolve, reject)
        local output_path = opts.output_path or
            (input_path:gsub('%.gz$', '') or input_path .. '.decompressed')

        local args = { '-k', '-d', input_path }

        local p = Process.spawn('gzip', args)

        p:on('exit', function(code)
            if code == 0 then
                resolve({
                    path = output_path,
                    meta = {
                        compressed_path = input_path,
                        original_path = output_path
                    }
                })
            else
                reject({
                    code = 'GUNZIP_FILE_ERROR',
                    message = ('Failed to decompress file: %s'):format(input_path),
                    exit_code = code
                })
            end
        end)
    end)
end

function M.decompress(input, opts)
    return Promise.new(function(resolve, reject)
        local input_type = opts.input_type

        -- 数据输入处理
        if input_type == 'data' then
            return decompress_data(input, opts)
                :forward(resolve)
                :catch(reject)
        end

        -- 文件处理
        if input_type == 'file' then
            return decompress_file(input, opts)
                :forward(resolve)
                :catch(reject)
        end

        reject({
            code = 'UNSUPPORTED_TYPE',
            message = ('Unsupported input type: %s'):format(input_type)
        })
    end)
end

return M
