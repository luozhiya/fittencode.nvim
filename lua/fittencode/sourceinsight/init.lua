--[[

local SI = require("sourceinsight")
SI.get_change(bufnr, changedtick)
这个函数可以获取指定缓冲区的指定时间点的变化，返回一个 table，包含了变化的行号和内容

FIM, 因为 FittenCode 的 FIM 只有一个接口，需要在请求补全的时候提交 Change，只有一次机会
T1 = T0 + 1, SI.get_change() 连续的触发FIM时，才发送Change
T1 > T0 + 1, 间断的则重发整个文档
对于超过 200 KB 的文档，frament 之后，计算 DIFF 很难，所以每次都发整个 fragment 内容

对于 Project
SI.get_snapshot(bufnr, changedtick)
返回一个 snapshot 对象，可以提取信息用于构建 Project Completion Prompt

对于 Context
SI.get_fragment(bufnr, position, threshold)
这个函数可以获取指定位置的上下文片段，threshold 控制上下文的大小

--]]

local M = {}

function M.init()
    -- 区别于 LSP 的 FileType 事件，我们允许在 noname buffer 里触发
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        pattern = '*',
        callback = function(args)
            vim.api.nvim_buf_attach(args.buf, false, {
                on_lines = function(buf, changedtick, firstline, lastline, new_lastline, old_byte_size, new_byte_size)
                end,
                on_reload = function(buf)
                end,
                on_detach = function(buf)
                end,
                utf_sizes = false,
            })
        end,
        desc = 'FittenCode filetype integration',
    })
end

function M.get_change(bufnr, changedtick)
end

function M.get_snapshot(bufnr, changedtick)
end

function M.get_fragment(bufnr, position, threshold)
end

return M
