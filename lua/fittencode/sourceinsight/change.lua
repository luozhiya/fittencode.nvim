--[[

实现对单个 Buffer 的 DIFF 计算
- FIM Protocol 可以利用该模块填充 diff 信息
- 但是 FIM 并不会每个 Change 都会采用。
  - 先考虑最简但的情况，每个 Change FIM 都会发送，且 Buffer 不会切换。
  - 如果 Change 有 Gap，提供 Merge Change 接口？
  - 又或者每一次 Change 都发送，但是 FIM 需要填写 PMD5 值，这就需要保证前一个 Change 发送成功且服务器接收处理才能发送下一个 Change，这样触发补全就会需要等待？。

Reference:
- nvim/runtime/lua/vim/lsp/_changetracking.lua

]]

---@class FittenCode.SourceInsight.BufferState
---@field name string
---@field lines string[]

local state = {}

local M = {}

function M.init(bufnr)
end

return M
