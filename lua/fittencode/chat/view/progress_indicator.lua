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
}

local progress_timer = nil
local current_frame = 1
local progress_win = nil
local progress_buf = nil

local function update_progress()
    if not progress_buf or not vim.api.nvim_buf_is_valid(progress_buf) then
        M.stop()
        return
    end

    vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, { config.frames[current_frame] })
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

    progress_win = vim.api.nvim_open_win(progress_buf, false, {
        relative = 'editor',
        width = 1,
        height = 1,
        row = height - 2,
        col = 0,
        style = 'minimal',
        focusable = false,
    })

    vim.api.nvim_set_option_value('winblend', 0, { win = progress_win })
    vim.api.nvim_set_option_value('winhl', 'Normal:' .. config.highlight_group, { win = progress_win })

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
