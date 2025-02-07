local spawn = require('zipflow.process.spawn')
local Promise = require('fittencode.concurrency.promise')
local uv = vim.uv or vim.loop

local M = {
    name = 'tar',
    type = 'cli',
    capabilities = {
        compress = {
            input_types = { 'directory' },
            output_types = { 'file' },
            formats = { 'tar' },
            compression = { 'none', 'gzip', 'bzip2', 'xz' }
        },
        decompress = {
            input_types = { 'file' },
            output_types = { 'directory' },
            formats = { 'tar', 'tar.gz', 'tar.bz2', 'tar.xz' }
        }
    }
}

local function detect_compression(format)
    local map = {
        ['tar.gz'] = 'z',
        ['tgz'] = 'z',
        ['tar.bz2'] = 'j',
        ['tar.xz'] = 'J'
    }
    return map[format] or ''
end

function M.compress(input_dir, opts)
    return Promise.new(function(resolve, reject)
        local output_path = opts.output_path or input_dir .. '.tar' .. (opts.format == 'tar' and '' or '.' .. opts.format:match('tar%.(.+)'))
        local compression_flag = detect_compression(opts.format)

        local args = {
            '-c',
            compression_flag and ('-' .. compression_flag) or nil,
            '-f', output_path,
            '-C', input_dir,
            '.'
        }

        local p = spawn('tar', args)

        p:on('exit', function(code)
            if code == 0 then
                resolve({
                    path = output_path,
                    meta = {
                        original_dir = input_dir,
                        compressed_path = output_path
                    }
                })
            else
                reject({
                    code = 'TAR_ERROR',
                    message = 'Tar compression failed',
                    exit_code = code
                })
            end
        end)
    end)
end

function M.decompress(input_file, opts)
    return Promise.new(function(resolve, reject)
        local output_dir = opts.output_path or input_file:gsub('%.tar.*', '')
        local compression_flag = detect_compression(path.extname(input_file))

        local args = {
            '-x',
            compression_flag and ('-' .. compression_flag) or nil,
            '-f', input_file,
            '-C', output_dir
        }

        uv.fs_mkdir(output_dir, 493) -- 0755 in decimal

        local p = spawn('tar', args)

        p:on('exit', function(code)
            if code == 0 then
                resolve({
                    path = output_dir,
                    meta = {
                        compressed_path = input_file,
                        output_dir = output_dir
                    }
                })
            else
                reject({
                    code = 'UNTAR_ERROR',
                    message = 'Tar decompression failed',
                    exit_code = code
                })
            end
        end)
    end)
end

return M
