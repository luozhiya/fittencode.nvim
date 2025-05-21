-- 进度指示器模块
local M = {}

-- 配置选项
local config = {
    frames = { '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' },
    update_interval = 150, -- 毫秒
    highlight_group = 'Comment',
}

-- 状态变量
local progress_timer = nil
local current_frame = 1
local progress_win = nil
local progress_buf = nil

-- 更新进度指示器显示
local function update_progress()
    if not progress_buf then
        return
    end

    vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, { config.frames[current_frame] })
    current_frame = (current_frame % #config.frames) + 1
end

-- 显示进度指示器
function M.start()
    if progress_timer then
        return
    end

    -- 创建浮动窗口
    progress_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(progress_buf, 'bufhidden', 'wipe')

    local width = vim.api.nvim_get_option('columns')
    local height = vim.api.nvim_get_option('lines')

    progress_win = vim.api.nvim_open_win(progress_buf, false, {
        relative = 'editor',
        width = 1,
        height = 1,
        row = height - 2,
        col = width - 2,
        style = 'minimal',
        focusable = false,
    })

    vim.api.nvim_win_set_option(progress_win, 'winblend', 0)
    vim.api.nvim_win_set_option(progress_win, 'winhl', 'Normal:' .. config.highlight_group)

    -- 启动计时器
    progress_timer = vim.loop.new_timer()
    progress_timer:start(0, config.update_interval, vim.schedule_wrap(update_progress))

    -- 初始更新
    update_progress()
end

function M.stop()
    if progress_timer then
        progress_timer:stop()
        progress_timer:close()
        progress_timer = nil
    end

    if progress_win and vim.api.nvim_win_is_valid(progress_win) then
        vim.api.nvim_win_close(progress_win, true)
        progress_win = nil
    end

    if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
        vim.api.nvim_buf_delete(progress_buf, { force = true })
        progress_buf = nil
    end

    current_frame = 1
end

function M.toggle()
    if progress_timer then
        M.stop()
    else
        M.start()
    end
end

-- function M.update(ctrl, event_type, data)
-- end

return M
