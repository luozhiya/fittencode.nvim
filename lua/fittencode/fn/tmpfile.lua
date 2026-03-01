local Promise = require('fittencode.fn.promise')

local M = {}

function M.with_tmpfile(data, callback, ...)
    local path
    local args = { ... }
    return Promise.promisify(vim.uv.fs_mkstemp)(vim.fn.tempname() .. '.FittenCode_TEMP_XXXXXX'):forward(function(handle)
        local fd = handle[1]
        path = handle[2]
        return Promise.promisify(vim.uv.fs_write)(fd, data):forward(function()
            return Promise.promisify(vim.uv.fs_close)(fd)
        end)
    end):forward(function()
        return callback(path, unpack(args))
    end):finally(function()
        Promise.promisify(vim.uv.fs_unlink)(path)
    end)
end

return M
