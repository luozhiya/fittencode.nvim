---@class FittenCode.Chat.View.Format
local Format = {}
Format.__index = Format

Format.HL_NS_NAME = 'fittencode-chat'

Format.HL_GROUP_USER_HEADER = 'FCChatUserHeader'
Format.HL_GROUP_BOT_HEADER = 'FCChatBotHeader'
Format.HL_GROUP_META = 'FCChatMeta'
Format.HL_GROUP_DIVIDER = 'FCChatDivider'
Format.HL_GROUP_ERROR = 'FCChatError'
Format.HL_GROUP_PROGRESS = 'FCChatProgress'

---@type table<string, table>
Format.rules = {
    user = {
        header = '## You',
        header_hl = Format.HL_GROUP_USER_HEADER,
        pad_before = 0,
        pad_after_header = 0,
        pad_after = 1,
    },
    bot = {
        header = '## Fitten Code',
        header_hl = Format.HL_GROUP_BOT_HEADER,
        pad_before = 0,
        pad_after_header = 0,
        pad_after = 1,
    },
    meta = {
        header = nil,
        header_hl = Format.HL_GROUP_META,
        content_prefix = '--- ',
        pad_before = 1,
        pad_after = 0,
    },
    error = {
        header = nil,
        prefix = '',
        hl = Format.HL_GROUP_ERROR,
        pad_before = 1,
        pad_after = 1,
    },
    progress = {
        header = nil,
        prefix = '',
        hl = Format.HL_GROUP_PROGRESS,
        pad_before = 1,
        pad_after = 0,
    },
}

Format.divider = {
    char = '─', -- U+2500 BOX DRAWINGS LIGHT HORIZONTAL
    hl = Format.HL_GROUP_DIVIDER,
    pad_before = 0,
    pad_after = 1,
}

---@return integer ns_id
function Format:get_ns_id()
    if not self._ns_id then
        self._ns_id = vim.api.nvim_create_namespace(Format.HL_NS_NAME)
    end
    return self._ns_id
end

function Format:define_highlights()
    vim.api.nvim_set_hl(0, Format.HL_GROUP_USER_HEADER, { fg = '#8ab4f8', bold = true, default = true })
    vim.api.nvim_set_hl(0, Format.HL_GROUP_BOT_HEADER, { fg = '#34a853', bold = true, default = true })
    vim.api.nvim_set_hl(0, Format.HL_GROUP_META, { fg = '#808080', italic = true, default = true })
    vim.api.nvim_set_hl(0, Format.HL_GROUP_DIVIDER, { fg = '#404040', default = true })
    vim.api.nvim_set_hl(0, Format.HL_GROUP_ERROR, { fg = '#ff6b6b', default = true })
    vim.api.nvim_set_hl(0, Format.HL_GROUP_PROGRESS, { fg = '#808080', italic = true, default = true })
end

---Detect fenced code blocks in message content
---Returns array of { start_line, end_line, lang } relative to message lines
---@param content string
---@return table[]
local function detect_code_blocks(content)
    local blocks = {}
    local lines = vim.split(content, '\n', { trimempty = false })
    local i = 0
    while i < #lines do
        local line = lines[i + 1]
        local lang = line:match('^```(%w+)$')
        if lang then
            local start_line = i
            i = i + 1
            while i < #lines do
                if lines[i + 1]:match('^```%s*$') then
                    blocks[#blocks + 1] = {
                        start_line = start_line,
                        end_line = i,
                        lang = lang,
                    }
                    break
                end
                i = i + 1
            end
        end
        i = i + 1
    end
    return blocks
end

---Render message content into styled lines
---@param msg FittenCode.Chat.Message
---@return string[] lines
---@return table[] extmark_blocks
function Format:render_message(msg)
    local rule = Format.rules[msg.author]
    if not rule then
        local fallback = vim.split(msg.content, '\n', { trimempty = false })
        return fallback, {}
    end

    local lines = {}
    local extmark_blocks = {}

    -- pad_before
    for _ = 1, rule.pad_before do
        lines[#lines + 1] = ''
    end

    if msg.author == 'meta' then
        local prefix = rule.content_prefix or ''
        lines[#lines + 1] = prefix .. msg.content
        extmark_blocks[#extmark_blocks + 1] = {
            start_line = #lines - 1,
            end_line = #lines,
            hl_group = rule.header_hl,
        }
    else
        if rule.header then
            lines[#lines + 1] = rule.header
            extmark_blocks[#extmark_blocks + 1] = {
                start_line = #lines - 1,
                end_line = #lines,
                hl_group = rule.header_hl,
            }
        end
        for _ = 1, (rule.pad_after_header or 0) do
            lines[#lines + 1] = ''
        end

        local code_blocks = detect_code_blocks(msg.content)
        local content_lines = vim.split(msg.content, '\n', { trimempty = false })
        local content_start = #lines
        for _, cl in ipairs(content_lines) do
            lines[#lines + 1] = cl
        end
        for _, cb in ipairs(code_blocks) do
            extmark_blocks[#extmark_blocks + 1] = {
                start_line = content_start + cb.start_line,
                end_line = content_start + cb.end_line,
                hl_group = nil,
                lang = cb.lang,
            }
        end
    end

    -- pad_after
    for _ = 1, rule.pad_after do
        lines[#lines + 1] = ''
    end

    return lines, extmark_blocks
end

---Render a horizontal divider
---@param width? integer
---@return string[] lines
function Format:render_divider(width)
    width = width or 40
    local char = Format.divider.char
    local line = string.rep(char, width)
    local lines = {}
    for _ = 1, Format.divider.pad_before do
        lines[#lines + 1] = ''
    end
    lines[#lines + 1] = line
    for _ = 1, Format.divider.pad_after do
        lines[#lines + 1] = ''
    end
    return lines
end

---Render an error message
---@param text string
---@return string[] lines
function Format:render_error(text)
    local rule = Format.rules.error
    local lines = {}
    for _ = 1, rule.pad_before do
        lines[#lines + 1] = ''
    end
    lines[#lines + 1] = (rule.prefix or '') .. text
    for _ = 1, rule.pad_after do
        lines[#lines + 1] = ''
    end
    return lines
end

---Render a progress indicator line
---@param text string
---@return string[] lines
function Format:render_progress(text)
    local rule = Format.rules.progress
    local lines = {}
    for _ = 1, rule.pad_before do
        lines[#lines + 1] = ''
    end
    lines[#lines + 1] = (rule.prefix or '') .. text
    for _ = 1, rule.pad_after do
        lines[#lines + 1] = ''
    end
    return lines
end

---Apply extmark highlights for header lines and special regions
---@param buf integer
---@param extmark_blocks table[]
---@param base_row integer 0-based row offset in buffer
function Format:apply_extmarks(buf, extmark_blocks, base_row)
    local ns_id = self:get_ns_id()
    for _, block in ipairs(extmark_blocks) do
        if block.hl_group then
            pcall(vim.api.nvim_buf_set_extmark, buf, ns_id,
                base_row + block.start_line, 0,
                {
                    end_row = base_row + block.end_line,
                    end_col = 0,
                    hl_group = block.hl_group,
                    hl_mode = 'combine',
                }
            )
        end
        if block.lang then
            pcall(vim.api.nvim_buf_set_extmark, buf, ns_id,
                base_row + block.start_line, 0,
                {
                    end_row = base_row + block.end_line,
                    end_col = -1,
                    hl_group = block.hl_group,
                    hl_mode = 'combine',
                }
            )
        end
    end
end

---Apply extmark to a specific line range
---@param buf integer
---@param start_row integer 0-based
---@param end_row integer 0-based exclusive
---@param hl_group string
function Format:apply_region_hl(buf, start_row, end_row, hl_group)
    local ns_id = self:get_ns_id()
    pcall(vim.api.nvim_buf_set_extmark, buf, ns_id,
        start_row, 0,
        {
            end_row = end_row,
            end_col = 0,
            hl_group = hl_group,
            hl_mode = 'combine',
        }
    )
end

---Clear all extmarks on a buffer for our namespace
---@param buf integer
function Format:clear_extmarks(buf)
    local ns_id = self:get_ns_id()
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)
end

---Ensure treesitter is active on the buffer for markdown + code block highlighting
---@param buf integer
function Format:ensure_treesitter(buf)
    local ok_ts, ts = pcall(require, 'vim.treesitter')
    if not ok_ts then
        return
    end
    local ok_parser, _ = pcall(ts.get_parser, buf, 'markdown')
    if not ok_parser then
        return
    end
    pcall(ts.start, buf, 'markdown')
end

return Format
