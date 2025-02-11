-- uv/udp.lua
local promise = require('fittencode.uv._promise')

return {
    bind = promise.promisify(vim.uv.udp_bind),
    send = promise.promisify(vim.uv.udp_send)
}
