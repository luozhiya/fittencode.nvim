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

local function selection_changed_callback()
end

function Editor.monaco()
    local buffer = vim.api.nvim_get_current_buf()
    return buffer
end

function Editor.get_selected()
    local function v()
        local modes = { ['v'] = true, ['V'] = true, [vim.api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }
        return modes[vim.api.nvim_get_mode().mode]
    end

    if v() then
        local region = vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = vim.fn.mode() })
        -- [bufnum, lnum, col, off]
        local regionpos = vim.fn.getregionpos(vim.fn.getpos('.'), vim.fn.getpos('v'))
        Log.debug('region = {}', region)
        Log.debug('regionpos = {}', regionpos)
    end

    local buffer = Editor.monaco()
    local start = vim.api.nvim_buf_get_mark(buffer, '<')
    local end_ = vim.api.nvim_buf_get_mark(buffer, '>')

    return {
        text = '',
        location = {
            row = 0,
            col = 0
        }
    }
end

function Editor.get_selected_text()
    return Editor.get_selected().text
end

function Editor.get_selected_range()
    local name = Editor.get_filename()
    local location = Editor.get_selected().location
    return name .. ' ' .. location.row .. ':' .. location.col
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
