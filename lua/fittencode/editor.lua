local Log = require('fittencode.log')

---@class fittencode.Editor
local Editor = {}

function Editor.get_ft_language()
    local ft = vim.bo.filetype
    -- Mapping vim filetype to vscode language-id ?
    return ft == '' and 'plaintext' or ft
end

function Editor.get_filename()
    return vim.api.nvim_buf_get_name(0)
end

function Editor.get_workspace_path()
    local workspace_path = vim.fn.getcwd()
    return workspace_path
end

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
