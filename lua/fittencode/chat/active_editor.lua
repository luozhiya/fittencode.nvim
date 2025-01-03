local Editor = require('fittencode.editor')

local M = {}

---@type integer?
local active_buf = nil

---@type FittenCode.Editor.Selection?
local selection = nil

---@type table<integer>
local filter_bufs = {}

function M.register_filter_buf(buf)
    filter_bufs[#filter_bufs + 1] = buf
end

---@return integer?
function M.buf()
    if M.is_filebuf(active_buf) then
        return active_buf
    end
end

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = vim.api.nvim_create_augroup('fittencode.editor.active', { clear = true }),
    pattern = '*',
    callback = function(args)
        if vim.tbl_contains(filter_bufs, args.buf) then
            return
        end
        if Editor.is_filebuf(args.buf) then
            active_buf = args.buf
            vim.api.nvim_exec_autocmds('User', { pattern = 'fittencode.ActiveChanged', modeline = false, data = args.buf })
        end
    end
})

vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    group = vim.api.nvim_create_augroup('fittencode.editor.selection', { clear = true }),
    pattern = '*',
    callback = function(args)
        if args.buf ~= M.buf() then
            return
        end
        local function v()
            local modes = { ['v'] = true, ['V'] = true, [vim.api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }
            return modes[vim.api.nvim_get_mode().mode]
        end
        if v() then
            local region = vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = vim.fn.mode() })
            local pos = vim.fn.getregionpos(vim.fn.getpos('.'), vim.fn.getpos('v'))
            local start = { pos[1][1][2], pos[1][1][3] }
            local end_ = { pos[#pos][2][2], pos[#pos][2][3] }
            selection = {
                buf = args.buf,
                name = vim.api.nvim_buf_get_name(args.buf),
                text = region,
                location = {
                    start_row = start[1],
                    start_col = start[2],
                    end_row = end_[1],
                    end_col = end_[2],
                }
            }
            vim.api.nvim_exec_autocmds('User', { pattern = 'fittencode.SelectionChanged', modeline = false, data = selection })
        end
    end,
    desc = 'Fittencode editor selection event',
})


function M.selection()
    return selection
end

function M.selected_text()
    local se = M.selection()
    if not se then
        return
    end
    return se.text
end

function M.selected_location_text()
end

function M.selected_range()
    local se = M.selection()
    if not se then
        return
    end
    return {
        name = se.name,
        start_row = se.location.start_row,
        end_row = se.location.end_row,
    }
end

function M.selected_text_with_diagnostics(opts)
    -- 1. Get selected text with lsp diagnostic info
    -- 2. Format
end

function M.diagnose_info()
    local error_code = ''
    local error_line = ''
    local surrounding_code = ''
    local error_message = ''
    local msg = [[The error code is:
\`\`\`
]] .. error_code .. [[
\`\`\`
The error line is:
\`\`\`
]] .. error_line .. [[
\`\`\`
The surrounding code is:
\`\`\`
]] .. surrounding_code .. [[
\`\`\`
The error message is: ]] .. error_message
    return msg
end

function M.error_location()
end

function M.title_selected_text()
end

return M
