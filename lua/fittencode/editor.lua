local Log = require('fittencode.log')

---@class fittencode.Editor
local Editor = {
    filter_bufs = {},
    active_buf = nil,
    selection = nil,
}

function Editor.get_ft_language()
    if not Editor.active_buf then
        return
    end
    local ft
    vim.api.nvim_buf_call(Editor.active_buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = Editor.active_buf })
    end)
    return ft
end

function Editor.get_filename()
    if not Editor.active_buf then
        return
    end
    local name
    vim.api.nvim_buf_call(Editor.active_buf, function()
        name = vim.api.nvim_buf_get_name(Editor.active_buf)
    end)
    return name
end

function Editor.get_workspace_path()
    if not Editor.active_buf then
        return
    end
    local ws
    vim.api.nvim_buf_call(Editor.active_buf, function()
        ws = vim.fn.getcwd()
    end)
    return ws
end

function Editor.register_filter_buf(buf)
    Editor.filter_bufs[#Editor.filter_bufs + 1] = buf
end

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = vim.api.nvim_create_augroup('fittencode.editor.active_buffer', { clear = true }),
    pattern = '*',
    callback = function(args)
        if vim.tbl_contains(Editor.filter_bufs, args.buf) then
            return
        end
        if vim.api.nvim_buf_is_valid(args.buf) and vim.api.nvim_buf_is_loaded(args.buf) and vim.fn.buflisted(args.buf) == 1 then
            Editor.active_buf = args.buf
            Log.debug('Active buffer changed to {}, name = {}', args.buf, vim.api.nvim_buf_get_name(args.buf))
        end
    end
})

vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    group = vim.api.nvim_create_augroup('fittencode.editor.selection', { clear = true }),
    pattern = '*',
    callback = function(args)
        local function v()
            local modes = { ['v'] = true, ['V'] = true, [vim.api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }
            return modes[vim.api.nvim_get_mode().mode]
        end
        if v() then
            local region = vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = vim.fn.mode() })
            local pos = vim.fn.getregionpos(vim.fn.getpos('.'), vim.fn.getpos('v'))
            local start = { pos[1][1][2], pos[1][1][3] }
            local end_ = { pos[#pos][2][2], pos[#pos][2][3] }
            Editor.selection = {
                buf = args.buf,
                text = region,
                location = {
                    start_row = start[1],
                    start_col = start[2],
                    end_row = end_[1],
                    end_col = end_[2],
                }
            }
            vim.api.nvim_exec_autocmds('User', { pattern = 'fittencode.SelectionChanged', modeline = false, data = Editor.selection })
        end
    end,
    desc = 'Fittencode editor selection event',
})

function Editor.get_selected()
    return Editor.selection
end

function Editor.get_selected_text()
    if not Editor.get_selected() then
        return
    end
    return Editor.get_selected().text
end

function Editor.get_selected_range()
    if not Editor.get_selected() then
        return
    end
    local name = Editor.get_filename()
    local location = Editor.get_selected().location
    return {
        name = name,
        start_row = location.start_row,
        end_row = location.end_row,
    }
end

function Editor.get_selected_text_with_diagnostics(opts)
    -- 1. Get selected text with lsp diagnostic info
    -- 2. Format
end

function Editor.get_diagnose_info()
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

function Editor.get_error_location()
    local error_location = ''
    return error_location
end

function Editor.get_title_selected_text()
    local title_selected_text = ''
    return title_selected_text
end

return Editor
