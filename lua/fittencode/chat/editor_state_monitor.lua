local Editor = require('fittencode.document.editor')

-- 监控编辑器状态变化，Vim 中只有 buffer，没有 VSCode 中的 activeTextEditor 概念
-- 1. 当前编辑的文件
-- 2. 当前选中的文本

local M = {}

-- 定义 state 表
local record_state = {
    last_active_buffer = nil,
    selection = nil,
    filter_buffers = {}
}

function M.register_filter_buf(buf)
    table.insert(record_state.filter_buffers, buf)
end

function M.unregister_filter_buf(buf)
    for i, v in ipairs(record_state.filter_buffers) do
        if v == buf then
            table.remove(record_state.filter_buffers, i)
            break
        end
    end
end

---@return integer?
function M.active_text_editor()
    if Editor.is_filebuf(record_state.last_active_buffer) then
        return record_state.last_active_buffer
    else
        M.clear_state()
    end
end

function M.selection()
    return record_state.selection
end

-- Chat 界面选择清除 Selection
function M.clear_selection()
    record_state.selection = nil
end

-- 清除选中状态
function M.clear_state()
    record_state.last_active_buffer = nil
    record_state.selection = nil
end

function M.selected_text()
    if not M.active_text_editor() then
        return
    end
    local selection = M.selection()
    if not selection then
        return
    end
    return selection.text
end

function M.selected_location_text()
end

function M.selected_range()
    local selection = M.selection()
    if not selection then
        return
    end
    return {
        name = selection.name,
        start_row = selection.location.start_row,
        end_row = selection.location.end_row,
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

function M.init()
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Editor.Active', { clear = true }),
        pattern = '*',
        callback = function(args)
            if vim.tbl_contains(record_state.filter_buffers, args.buf) then
                return
            end
            if Editor.is_filebuf(args.buf) then
                record_state.last_active_buffer = args.buf
                vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCode.ActiveChanged', modeline = false, data = args.buf })
            end
        end
    })

    -- 切换文档不影响选中状态
    -- 只有当在活动文档中输入状态下则清除Selection
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Editor.Selection', { clear = true }),
        pattern = '*',
        callback = function(args)
            if args.buf ~= M.active_text_editor() then
                return
            end
            local function _check_v()
                local modes = { ['v'] = true, ['V'] = true, [vim.api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }
                return modes[vim.api.nvim_get_mode().mode]
            end
            if not _check_v() then
                record_state.selection = nil
                vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCode.SelectionChanged', modeline = false, data = record_state.selection })
            else
                local region = vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = vim.fn.mode() })
                local pos = vim.fn.getregionpos(vim.fn.getpos('.'), vim.fn.getpos('v'))
                local start = { pos[1][1][2], pos[1][1][3] }
                local end_ = { pos[#pos][2][2], pos[#pos][2][3] }
                record_state.selection = {
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
                vim.api.nvim_exec_autocmds('User', { pattern = 'FittenCode.SelectionChanged', modeline = false, data = record_state.selection })
            end
        end,
        desc = 'Fittencode editor selection event',
    })
end

return M
