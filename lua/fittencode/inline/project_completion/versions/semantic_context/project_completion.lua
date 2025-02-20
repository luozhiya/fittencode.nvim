local Fn = require('fittencode.functional.fn')
local Editor = require('fittencode.document.editor')
local LspService = require('fittencode.functional.lsp_service')
local Comment = require('fittencode.inline.project_completion.comment')
local Spec = require('fittencode.inline.project_completion.spec')
local Format = require('fittencode.functional.format')

local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

-- 配置参数
local MAX_LENGTH = 20000 -- 最大提示长度
local MAX_ITEMS = 5

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

function ProjectCompletion.new(mode, format)
    local self = setmetatable({}, ProjectCompletion)
    self.mode = mode
    self.format = format
    return self
end

-- 定义不同模式下需要执行的操作
local pipes = {
    ['fast'] = {
    },
    ['balanced'] = {
    },
    ['precise'] = {
    }
}

--[[
// a.h
struct A {
    int a;
};

// main.cpp
#include "a.h"
int main() {
    A a;
    a.<cursor>
}
--]]

--[[
Item
    uri
    definition
    compressed_code
--]]

local function compose_prompt(items, format, order)
    local title_template = Spec.format[format]

    local prompts = {}
    for _, item in ipairs(items) do
        if not item.compressed_code or #item.compressed_code == 0 then
            ::continue::
        end
        local title = Format.format(title_template, item.uri, item.definition)
        local prompt = title .. '\n' .. table.concat(item.compressed_code, '\n')
        table.insert(prompts, prompt)
    end

    if order == 'reversed' then
        prompts = Fn.reverse(prompts)
    end

    return table.concat(prompts, '\n\n')
end

-- 利用 TreeSitter 获取指定代码块的最简描述
local function compressed_code(buf, range)
    -- 1. 如果 Range 是类，则返回类成员+方法
    -- 2. 如果 Range 是函数，则返回函数声明+精简函数体
    --
end

-- 生成提示内容
function ProjectCompletion:get_prompt_sync(buf, postion, mode, format)
    mode = mode or self.mode
    format = format or self.format

    -- 1.0 流程
    -- 1 根据 mode 选择不同的流水线
    -- 2 执行流水线
    -- 3 根据 format 生成 prompt

    -- 2.0 流程
    -- 1. TS 分析当前 cursor 所属的 block （block有各种范围？）
    -- 2. 提取 TS 中的函数、类型 (T0)
    -- 3. 通过 LSP 获取当前文档中符号 (过滤，保留函数、类型) T1
    -- 4. 对不属于 T1 的 T0 中的每一个元素，通过 LSP 获取定义位置
    -- 5. 加载定义位置代码，TS 分析代码块 (TS 会很慢？)，生成模块最简描述
    -- 6. 合成 Prompt

    local context_symbol = get_context_symbol(buf, postion)
    if not context_symbol then
        return ''
    end

    local definitions = get_symbol_definitions(buf, postion)
    if not definitions or #definitions == 0 then
        return ''
    end

    local lang = vim.bo[buf].filetype
    local comment_pattern = Comment.line_pattern(lang) or ''
    local title_template = Spec.format[format]

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
            print('Error fetching code lines for URI: ' .. target_uri)
            return prompt
        end

        local code = compress_code(code_lines)
        local header = ''
        local symbol = ''

        if format == 'concise' then
            header = Format.format(title_template, comment_pattern, target_uri)
        elseif format == 'redundant' then
            header = Format.format(title_template, comment_pattern, target_uri, symbol)
        end

        prompt = prompt .. header .. '\n' .. code .. '\n\n'
        count = count + 1

        if #prompt > MAX_LENGTH then
            prompt = prompt:sub(1, MAX_LENGTH)
            break
        end
    end

    return prompt
end

return ProjectCompletion
