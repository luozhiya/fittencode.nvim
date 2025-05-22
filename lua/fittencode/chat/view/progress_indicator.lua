local M = {}

local styles = {
    spin = { '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' },
    line = { '|', '/', '-', '\\' },
    dots = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
    bars = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█', '▇', '▆', '▅', '▄', '▃', '▂', '▁' },
    arrows = { '←', '↖', '↑', '↗', '→', '↘', '↓', '↙' },
    pulse = { '█', '▓', '▒', '░', ' ', '░', '▒', '▓' },
    bounce = { '●', '•', ' ', '•', '●' },
    grow = { '.', '..', '...', '....', '.....', '......' },
    blocks = { '□', '■' },
    circle = { '○', '◔', '◑', '◕', '●' },
    moon = { '🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘' },
}

local config = {
    frames = styles.spin,
    update_interval = 150, -- 毫秒
    highlight_group = 'Comment',
    -- time_format = ' [%.0fms]',    -- 时间显示格式
    time_format = ' [%.2fs]',     -- 显示为秒，保留一位小数
    time_highlight = 'Statement', -- 时间文本高亮组
}

local progress_timer = nil
local current_frame = 1
local progress_win = nil
local progress_buf = nil
local start_time = nil

local function update_progress()
    if not progress_buf or not vim.api.nvim_buf_is_valid(progress_buf) then
        M.stop()
        return
    end

    local elapsed = vim.loop.hrtime() - start_time
    local elapsed_ms = elapsed / 1e9 -- 转换为毫秒

    local time_str = string.format(config.time_format, elapsed_ms)
    local content = config.frames[current_frame] .. time_str

    vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, { content })

    -- 设置时间部分的高亮
    --   if progress_win and vim.api.nvim_win_is_valid(progress_win) then
    --     local time_start = #config.frames[current_frame] + 1
    --     vim.api.nvim_buf_add_highlight(
    --       progress_buf,
    --       -1,
    --       config.time_highlight,
    --       0,
    --       time_start,
    --       -1
    --     )
    --   end

    current_frame = (current_frame % #config.frames) + 1
end

function M.start()
    if progress_timer then
        return
    end

    progress_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = progress_buf })

    local width = vim.api.nvim_get_option_value('columns', {})
    local height = vim.api.nvim_get_option_value('lines', {})

    -- 计算窗口宽度
    local max_frame_width = 0
    for _, frame in ipairs(config.frames) do
        max_frame_width = math.max(max_frame_width, #frame)
    end
    local time_width = #string.format(config.time_format, 10000)
    local win_width = max_frame_width + time_width

    progress_win = vim.api.nvim_open_win(progress_buf, false, {
        relative = 'editor',
        width = win_width, -- 1
        height = 1,
        row = height - 2,
        col = 0,
        style = 'minimal',
        focusable = false,
    })

    vim.api.nvim_set_option_value('winblend', 0, { win = progress_win })
    vim.api.nvim_set_option_value('winhl', 'Normal:' .. config.highlight_group, { win = progress_win })

    -- 记录开始时间
    start_time = vim.loop.hrtime()

    progress_timer = vim.loop.new_timer()
    assert(progress_timer)
    progress_timer:start(0, config.update_interval, vim.schedule_wrap(update_progress))

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
    end
    progress_win = nil

    if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
        vim.api.nvim_buf_delete(progress_buf, { force = true })
    end
    progress_buf = nil
    start_time = nil
    current_frame = 1
end

function M.toggle()
    if progress_timer then
        M.stop()
    else
        M.start()
    end
end

return M
