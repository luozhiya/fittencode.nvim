local M = {}

M.new = require('fittencode.vim.promisify.uv.spawn').new
M.spawn_promise = require('fittencode.vim.promisify.uv.spawn_promise').spawn_promise

return M
