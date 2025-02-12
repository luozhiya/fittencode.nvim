local M = {}

M.spawn = require('fittencode.vim.promisify.uv.spawn').spawn
M.spawn_promise = require('fittencode.vim.promisify.uv.spawn_promise').spawn_promise

return M
