--[[

aerial.nvim/lua/aerial/backends/treesitter/init.lua

Capture
- symbol
- name (optional)

query.iter_group_results return values:
{
    kind = "Method",
    name = {
    metadata = {
        range = { 2, 11, 2, 20 }
    },
    node = <userdata 1>
    },
    type = {
    node = <userdata 2>
    }
}

]]

local helpers = require('fittencode.inline.pc.treesitter.helpers')
local Log = require('fittencode.log')
local Promise = require('fittencode.fn.promise')

local M = {}

---@param bufnr integer
---@param mode 'dep' | 'ctx'
---@return nil|vim.treesitter.LanguageTree parser
---@return nil|vim.treesitter.Query query
local function get_lang_and_query(bufnr, mode)
    local parser = helpers.get_parser(bufnr)
    if not parser then
        return
    end
    local lang = parser:lang()
    local query = helpers.get_query(lang, mode)
    if not query then
        return
    end
    return parser, query
end

---@param bufnr integer
---@return boolean
M.is_supported = function(bufnr, mode)
    return get_lang_and_query(bufnr, mode) ~= nil
end

---@param bufnr integer
---@param lang string
---@param query vim.treesitter.Query
---@param syntax_tree? TSTree
local function symbols_from_treesitter(bufnr, lang, query, syntax_tree)
    local items = {}
    if not syntax_tree then
        return items
    end
    for _, matches, metadata in query:iter_matches(syntax_tree:root(), bufnr, nil, nil) do
        --- Matches can overlap. The last match wins.
        local match = vim.tbl_extend('force', {}, metadata)
        for id, nodes in pairs(matches) do
            -- preserve the old iter_matches({all = false}) behavior
            local node = nodes[#nodes]
            -- iter_group_results prefers `#set!` metadata, keeping the behaviour
            match = vim.tbl_extend('keep', match, {
                [query.captures[id]] = {
                    metadata = metadata[id],
                    node = node,
                },
            })
        end

        local name_match = match.name or {}
        local symbol_node = (match.symbol or {}).node
        if not symbol_node then
            goto continue
        end

        local kind = match.kind
        if not kind then
            break
        elseif not vim.lsp.protocol.SymbolKind[kind] then
            break
        end
        local range = helpers.range_from_nodes(symbol_node, symbol_node)
        local name
        if name_match.node then
            name = vim.treesitter.get_node_text(name_match.node, bufnr, name_match) or '<parse error>'
        else
            name = '<Anonymous>'
        end
        local item = {
            kind = kind,
            name = name,
            range = range,
        }
        table.insert(items, item)

        ::continue::
    end
    return items
end

---@param bufnr integer
---@return FittenCode.Promise
M.fetch_symbols = function(bufnr, mode)
    local parser, query = get_lang_and_query(bufnr, mode)
    assert(parser)
    assert(query)

    return Promise.new(function(resolve, reject)
        parser:parse(nil, function(err, syntax_trees)
            if err then
                return reject(err)
            else
                assert(syntax_trees)
                local lang = parser:lang()
                return resolve(symbols_from_treesitter(bufnr, lang, query, syntax_trees[1]))
            end
        end)
    end)
end

return M
