local M = {}

M.create = require('fittencode.vim.promisify.uv.spawn').create
M.spawn_promise = require('fittencode.vim.promisify.uv.spawn_promise').spawn_promise

return M
