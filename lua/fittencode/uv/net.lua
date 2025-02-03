-- lua/fittencode/uv/net.lua
local uv = vim.uv
local _Promise = require('fittencode.uv._promise')

local M = {}

M.tcp = {
    connect = _Promise.promisify(function(host, port, callback)
        local client = uv.new_tcp()
        client:connect(host, port, callback)
    end, { multi_args = true }),

    bind = _Promise.promisify(uv.tcp_bind),

    listen = _Promise.promisify(function(handle, backlog, callback)
        handle:listen(backlog, callback)
    end)
}

return M
