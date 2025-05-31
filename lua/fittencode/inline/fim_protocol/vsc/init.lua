local M = {}

local Gen = require('fittencode.inline.fim_protocol.vsc.generate')

M.generate = Gen.generate
M.update_version = Gen.update_version
M.parse = require('fittencode.inline.fim_protocol.vsc.parse')

return M
