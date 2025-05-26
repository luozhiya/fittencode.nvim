local Fn = require('fittencode.fn.core')

---@class FittenCode.View.ProgressIndicator
local ProgressIndicator = {}
ProgressIndicator.__index = ProgressIndicator

local STYLES = {
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

function ProgressIndicator.new(options)
    local self = setmetatable({}, ProgressIndicator)
    self:__initialize(options)
    return self
end

function ProgressIndicator:__initialize(options)
    options = options or {}
    self.frames = options.style or STYLES.spin
    self.update_interval = 150        -- 毫秒
    self.highlight_group = 'Comment'
    self.time_format = ' [%.2fs]'     -- 显示为秒，保留一位小数 -- ' [%.0fms]'    -- 时间显示格式
    self.time_highlight = 'Statement' -- 时间文本高亮组
    self.progress_timer = nil
    self.current_frame = 1
    self.progress_win = nil
    self.progress_buf = nil
    self.progress_start_time = nil
    self.ns = vim.api.nvim_create_namespace('FittenCode.View.ProgressIndicator.' .. Fn.generate_short_id())
end

function ProgressIndicator:update_progress()
    if not self.progress_buf or not vim.api.nvim_buf_is_valid(self.progress_buf) then
        self:stop()
        return
    end

    local elapsed = vim.loop.hrtime() - self.progress_start_time
    local elapsed_ms = elapsed / 1e9 -- 转换为毫秒

    local time_str = string.format(self.time_format, elapsed_ms)
    local content = self.frames[self.current_frame] .. time_str

    vim.api.nvim_buf_set_lines(self.progress_buf, 0, -1, false, { content })

    -- 设置时间部分的高亮
    if self.progress_win and vim.api.nvim_win_is_valid(self.progress_win) then
        local time_start = #self.frames[self.current_frame] + 1
        vim.hl.range(
            self.progress_buf,
            self.ns,
            self.time_highlight,
            { 0, 0 },
            { 0, time_start }
        )
    end

    self.current_frame = (self.current_frame % #self.frames) + 1
end

function ProgressIndicator:start(start_time)
    if self.progress_timer then
        return
    end

    self.progress_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = self.progress_buf })

    local width = vim.api.nvim_get_option_value('columns', {})
    local height = vim.api.nvim_get_option_value('lines', {})

    -- 计算窗口宽度
    local max_frame_width = 0
    for _, frame in ipairs(self.frames) do
        max_frame_width = math.max(max_frame_width, #frame)
    end
    local time_width = #string.format(self.time_format, 10000)
    local win_width = max_frame_width + time_width

    self.progress_win = vim.api.nvim_open_win(self.progress_buf, false, {
        relative = 'editor',
        width = win_width, -- 1
        height = 1,
        row = height - 2,
        col = 0, -- width - 2
        style = 'minimal',
        focusable = false,
    })

    vim.api.nvim_set_option_value('winblend', 0, { win = self.progress_win })
    vim.api.nvim_set_option_value('winhl', 'Normal:' .. self.highlight_group, { win = self.progress_win })

    self.progress_start_time = start_time

    self.progress_timer = vim.loop.new_timer()
    assert(self.progress_timer)
    self.progress_timer:start(0, self.update_interval, vim.schedule_wrap(function() self:update_progress() end))

    self:update_progress()
end

function ProgressIndicator:stop()
    if self.progress_timer then
        self.progress_timer:stop()
        self.progress_timer:close()
        self.progress_timer = nil
    end

    if self.progress_win and vim.api.nvim_win_is_valid(self.progress_win) then
        vim.api.nvim_win_close(self.progress_win, true)
    end
    self.progress_win = nil

    if self.progress_buf and vim.api.nvim_buf_is_valid(self.progress_buf) then
        vim.api.nvim_buf_delete(self.progress_buf, { force = true })
    end
    self.progress_buf = nil
    self.progress_start_time = nil
    self.current_frame = 1
end

function ProgressIndicator:toggle()
    if self.progress_timer then
        self.ProgressIndicator.stop()
    else
        self.ProgressIndicator.start()
    end
end

return ProgressIndicator
