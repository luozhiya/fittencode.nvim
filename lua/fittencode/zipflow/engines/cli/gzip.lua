local Spawn = require('fittencode.process.spawn')
local Promise = require('fittencode.concurrency.promise')

local M = {
    supported = {
        compress = { 'gzip', 'gz' },
        decompress = { 'gzip', 'gz' }
    }
}

local function check_availability()
    local p = Spawn.spawn('gzip', { '--version' })
    local promise = Promise.new(function(resolve)
        p:on('exit', function(code)
            resolve(code == 0)
        end)
        p:on('error', resolve)
    end)
    return promise
end

function M._setup()
    check_availability():forward(function(available)
        if not available then
            M.supported = { compress = {}, decompress = {} }
        end
    end)
end

local function gzip_process(args, input)
    return Promise.new(function(resolve, reject)
        local p = Spawn.spawn('gzip', args, { stdin = input })
        local output = {}

        p:on('stdout', function(data)
            table.insert(output, data)
        end)

        p:on('exit', function(code)
            if code == 0 then
                resolve(table.concat(output))
            else
                reject('Process exited with code ' .. code)
            end
        end)

        p:on('error', reject)
    end)
end

function M.compress(input, algorithm)
    return gzip_process({ '-c', '--best' }, input)
end

function M.decompress(input, algorithm)
    return gzip_process({ '-d', '-c' }, input)
end

return M
