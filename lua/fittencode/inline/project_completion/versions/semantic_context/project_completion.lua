local Fn = require('fittencode.functional.fn')
local Editor = require('fittencode.document.editor')
local LspService = require('fittencode.functional.lsp_service')

local M = {}

-- 配置参数
local MAX_LENGTH = 20000 -- 最大提示长度

local COMMENT_PATTERNS = {
    ['python'] = '#<content>',
    ['c'] = '//<content>',
    ['cpp'] = '//<content>',
    ['csharp'] = '//<content>',
    ['kotlin'] = '//<content>',
    ['java'] = '//<content>',
    ['javascript'] = '//<content>',
    ['typescript'] = '//<content>',
    ['php'] = '//<content>',
    ['go'] = '//<content>',
    ['rust'] = '//<content>',
    ['ruby'] = '#<content>',
    ['lua'] = '--<content>',
    ['perl'] = '#<content>',
    ['css'] = '/*<content>*/',
    ['matlab'] = '%<content>',
    ['unknown'] = '//<content>'
}

-- 获取语言注释模式
local function get_lang_title(filetype)
    local pattern = COMMENT_PATTERNS[filetype] or COMMENT_PATTERNS['unknown']
    return pattern:gsub('<content>', ' Below is partial code of %s for %s %s:')
end

-- 压缩代码
local function compress_code(lines)
    local compressed = {}
    for _, line in ipairs(lines) do
        local trimmed = line:gsub('^%s+', ''):gsub('%s+$', '')
        if #trimmed > 0 and not trimmed:match('^%-%-') and not trimmed:match('^//') and not trimmed:match('^#') and not trimmed:match('^%%') and not trimmed:match('^/%*') then
            table.insert(compressed, trimmed)
        end
    end
    return table.concat(compressed, '\n')
end

-- 获取符号定义
local function get_symbol_definitions(bufnr, pos)
    local params = vim.lsp.util.make_position_params(pos, bufnr)
    local result = vim.lsp.buf_request_sync(bufnr, 'textDocument/definition', params)

    if not result or vim.tbl_isempty(result) then
        return nil
    end

    local definitions = {}
    for _, res in pairs(result) do
        if res.result and not vim.tbl_isempty(res.result) then
            for _, item in ipairs(res.result) do
                table.insert(definitions, item)
            end
        end
    end

    return definitions
end

-- 获取上下文符号
local function get_context_symbol(bufnr, pos)
    local ts_utils = require('nvim-treesitter.ts_utils')
    local node = ts_utils.get_node_at_cursor()

    while node do
        local node_type = node:type()
        if node_type:find('identifier') or node_type:find('function') then
            local symbol_name = ts_utils.get_node_text(node, bufnr)[1]
            return {
                name = symbol_name,
                range = {
                    start = { line = node:start(), character = 0 },
                    ['end'] = { line = node:end_(), character = 0 }
                }
            }
        end
        node = node:parent()
    end

    return nil
end

-- 生成提示内容
function M.get_prompt()
    local bufnr = vim.api.nvim_get_current_buf()
    local pos = vim.api.nvim_win_get_cursor(0)
    pos = { line = pos[1] - 1, character = pos[2] } -- 转换为LSP位置

    local context_symbol = get_context_symbol(bufnr, pos)
    if not context_symbol then
        return ''
    end

    local definitions = get_symbol_definitions(bufnr, pos)
    if not definitions or #definitions == 0 then
        return ''
    end

    local lang = vim.bo[bufnr].filetype
    local title = get_lang_title(lang)
    local prompt = ''
    local count = 0

    for _, def in ipairs(definitions) do
        if count >= MAX_ITEMS then
            break
        end

        local target_uri = def.targetUri or def.uri
        local target_range = def.targetRange or def.range

        -- 跳转到定义位置获取代码
        local success, code_lines = pcall(vim.api.nvim_buf_get_lines, vim.uri_to_bufnr(target_uri), target_range.start.line, target_range['end'].line + 1, false)
        if not success then
            print("Error fetching code lines for URI: " .. target_uri)
            return prompt
        end

        local code = compress_code(code_lines)
        local symbol_type = node:type():find('identifier') and 'variable' or 'function'

        local header = string.format(
            title,
            target_uri,
            symbol_type,
            context_symbol.name
        )

        prompt = prompt .. header .. '\n' .. code .. '\n\n'
        count = count + 1

        if #prompt > MAX_LENGTH then
            prompt = prompt:sub(1, MAX_LENGTH)
            break
        end
    end

    return prompt
end

return M
