-- lua/hash/engines/md5sum.lua
local M = {
    name = 'md5sum',
    supported_hashes = { 'md5' },
    is_available = false,
}

if vim.fn.executable('md5sum') == 1 then
    M.is_available = true
end

function M.hash(_, input, is_file)
    return vim.promise.new(function(resolve, reject)
        if not is_file then
            -- 使用进程替换
            local handle = io.popen('printf "%s" "' .. input .. '" | md5sum', 'r')
            local result = handle:read('*a')
            handle:close()
            resolve(result:match('^([%w]+)'))
        else
            local stdout = {}
            local handle = vim.loop.spawn('md5sum', {
                args = { input },
            }, function(code)
                if code ~= 0 then return reject('Exit code: ' .. code) end
                resolve(string.match(table.concat(stdout), '^([%a%d]+)'))
            end)
            vim.loop.read_start(handle, function(_, data)
                if data then table.insert(stdout, data) end
            end)
        end
    end)
end

return M
