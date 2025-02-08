local uv = vim.loop
local lsp = vim.lsp
local api = vim.api

-- 符号树节点结构
local SymbolNode = {}
SymbolNode.__index = SymbolNode

function SymbolNode.new(name, kind, range, parent)
    return setmetatable({
        name = name,
        kind = kind,
        range = range,
        parent = parent,
        children = {},
        variables = {}
    }, SymbolNode)
end

-- LSP 管理器
local LSPManager = {}
LSPManager.__index = LSPManager

function LSPManager.new()
    return setmetatable({
        installed_servers = {},
        language_map = {
            python = 'pyright',
            lua = 'sumneko_lua',
            -- 添加更多语言映射...
        }
    }, LSPManager)
end

function LSPManager:check_installed(lang)
    local server = self.language_map[lang]
    return self.installed_servers[server] ~= nil
end

-- 项目补全类
local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

function ProjectCompletion.new()
    return setmetatable({
        symbol_trees = {},
        lsp_manager = LSPManager.new(),
        pending_requests = {}
    }, ProjectCompletion)
end

function ProjectCompletion:get_symbol_tree(bufnr)
    if not self.symbol_trees[bufnr] then
        self.symbol_trees[bufnr] = {
            root = SymbolNode.new('__root__', 'root', { start = { line = 0 }, ['end'] = { line = 0 } }),
            version = 0
        }
    end
    return self.symbol_trees[bufnr]
end

-- 递归构建符号树
local function build_symbol_tree(symbols, parent, buf)
    for _, symbol in ipairs(symbols) do
        local node = SymbolNode.new(
            symbol.name,
            symbol.kind,
            symbol.range,
            parent
        )

        -- 处理子符号
        if symbol.children then
            build_symbol_tree(symbol.children, node, buf)
        end

        -- 收集变量信息
        if node.kind == lsp.protocol.SymbolKind.Variable then
            parent.variables[node.name] = parent.variables[node.name] or {}
            table.insert(parent.variables[node.name], node)
        end

        parent.children[node.name] = node
    end
end

-- 异步更新符号树
function ProjectCompletion:update_symbols(buf)
    local bufnr = api.nvim_buf_get_number(buf)
    local lang = api.nvim_buf_get_option(buf, 'filetype')

    -- 检查 LSP 是否可用
    if not self.lsp_manager:check_installed(lang) then
        vim.notify('LSP server for ' .. lang .. ' not installed')
        return
    end

    local params = {
        textDocument = lsp.util.make_text_document_params(buf)
    }

    self.pending_requests[bufnr] = uv.now()

    lsp.buf_request(buf, 'textDocument/documentSymbol', params, function(err, result)
        if self.pending_requests[bufnr] == nil then return end

        local tree = self:get_symbol_tree(bufnr)
        tree.root = SymbolNode.new('__root__', 'root', { start = { line = 0 }, ['end'] = { line = 0 } })

        if not err and result then
            build_symbol_tree(result, tree.root, buf)
            tree.version = tree.version + 1
        end

        self.pending_requests[bufnr] = nil
    end)
end

-- 生成上下文提示
function ProjectCompletion:generate_prompt(buf, line)
    local tree = self:get_symbol_tree(buf)
    local prompt = {}
    local current_scope

    -- 查找当前作用域
    local function find_scope(node)
        for _, child in pairs(node.children) do
            if child.range.start.line <= line and child.range['end'].line >= line then
                current_scope = child
                find_scope(child)
            end
        end
    end

    find_scope(tree.root)

    -- 收集上下文信息
    if current_scope then
        table.insert(prompt, 'Current scope: ' .. current_scope.name)

        -- 收集父作用域链
        local parent = current_scope.parent
        while parent and parent.name ~= '__root__' do
            table.insert(prompt, 1, 'Parent scope: ' .. parent.name)
            parent = parent.parent
        end

        -- 收集相关变量
        local vars = {}
        for name, nodes in pairs(current_scope.variables) do
            table.insert(vars, name)
        end
        if #vars > 0 then
            table.insert(prompt, 'Variables in scope: ' .. table.concat(vars, ', '))
        end
    end

    return table.concat(prompt, '\n')
end

-- 使用示例
local completion = ProjectCompletion.new()

-- 绑定自动更新
api.nvim_create_autocmd({ 'BufEnter', 'TextChanged' }, {
    callback = function(args)
        completion:update_symbols(args.buf)
    end
})

-- 获取提示
function GetCompletionPrompt()
    local buf = api.nvim_get_current_buf()
    local line = api.nvim_win_get_cursor(0)[1]
    return completion:generate_prompt(buf, line - 1) -- line is 0-based
end

return ProjectCompletion
