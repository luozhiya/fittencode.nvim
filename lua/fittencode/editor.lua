local Log = require('fittencode.log')

---@class fittencode.Editor
local Editor = {
    selection = nil,
}

---@type integer?
local active = nil

local filter_bufs = {}

---@return string?
function Editor.ft_vsclang()
    local buf = Editor.active()
    if not buf then
        return
    end
    local ft
    vim.api.nvim_buf_call(buf, function()
        ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    end)
    -- Mapping vim filetype to vscode language
    if ft == '' then
        ft = 'plaintext'
    end
    return ft
end

---@return string?
function Editor.filename()
    local buf = Editor.active()
    if not buf then
        return
    end
    local name
    vim.api.nvim_buf_call(buf, function()
        name = vim.api.nvim_buf_get_name(buf)
    end)
    return name
end

---@return string?
function Editor.content()
    local buf = Editor.active()
    if not buf then
        return
    end
    local content
    vim.api.nvim_buf_call(buf, function()
        content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end)
    return content
end

function Editor.workspace_path()
    local buf = Editor.active()
    if not buf then
        return
    end
    local ws
    vim.api.nvim_buf_call(buf, function()
        ws = vim.fn.getcwd()
    end)
    return ws
end

function Editor.register_filter_buf(buf)
    filter_bufs[#filter_bufs + 1] = buf
end

function Editor.filebuffer(buf)
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.fn.buflisted(buf) == 1 then
        local path
        vim.api.nvim_buf_call(buf, function()
            path = vim.fn.expand('%:p')
        end)
        if vim.api.nvim_buf_get_name(buf) ~= '' and path and vim.fn.filereadable(path) == 1 then
            return true
        end
    end
    return false
end

---@return integer?
function Editor.active()
    if Editor.filebuffer(active) then
        return active
    end
end

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = vim.api.nvim_create_augroup('fittencode.editor.active', { clear = true }),
    pattern = '*',
    callback = function(args)
        if vim.tbl_contains(filter_bufs, args.buf) then
            return
        end
        if Editor.filebuffer(args.buf) then
            active = args.buf
            vim.api.nvim_exec_autocmds('User', { pattern = 'fittencode.ActiveChanged', modeline = false, data = args.buf })
            Log.debug('Active buffer changed to id = {}, name = {}', args.buf, vim.api.nvim_buf_get_name(args.buf))
        end
    end
})

vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    group = vim.api.nvim_create_augroup('fittencode.editor.selection', { clear = true }),
    pattern = '*',
    callback = function(args)
        if args.buf ~= Editor.active() then
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

function Editor.selected()
    return Editor.selection
end

function Editor.selected_text()
    if not Editor.selected() then
        return
    end
    return Editor.selected().text
end

function Editor.selected_location_text()
end

function Editor.selected_range()
    if not Editor.selected() then
        return
    end
    local name = Editor.filename()
    local location = Editor.selected().location
    return {
        name = name,
        start_row = location.start_row,
        end_row = location.end_row,
    }
end

function Editor.selected_text_with_diagnostics(opts)
    -- 1. Get selected text with lsp diagnostic info
    -- 2. Format
end

function Editor.diagnose_info()
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

function Editor.error_location()
    local error_location = ''
    return error_location
end

function Editor.title_selected_text()
    local title_selected_text = ''
    return title_selected_text
end

return Editor
