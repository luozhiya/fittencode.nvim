--[[

1. 通过 TS 解析 import、include 指令，获取依赖文件列表
2. 通过 LSP 请求 defination 获取每一个依赖的具体路径
3. 打开依赖文件，检查已有buffer中是否打开了，没有则打开一个新的buffer
4. 在buffer中使用 lsp 获取 documentSymbol 信息，并格式化输出

关于TS
- TS 是比较慢的，而且解析脚本比lsp复杂
- 每加一个类型就要对那个类型写大量类型query，所以只用ts来做引入分析，其他全用lsp

性能
- 只解析一层依赖
- 用map以文件路径为key，缓存已打开的buffer和 <context, version> 信息
- 如果一个buffer的版本没有改变，则返回缓存的prompt
- 如果一个buffer的版本改变数量比较小，那么在追求性能时，可以采用缓存prompt
- 如果一个buffer的版本改变数量比较大，那么可以考虑清理缓存
- 默认文件只会在neovim中被改变，暂不考虑外部修改文件的问题
    - 如果加载到buffer后，neovim会自动加载外部修改，那么可以按版本更新来同一处理
- 第一次访问时 cache[uri] > cache[ref-uri] = Promise, 然后直接返回
    - 在 cache[ref-uri] = Promise 中做一个回调，处理完了把 cache[ref-uri] = result 存入缓存

多重触发
- 如果B引入A，B解析A时，用户跳到A，触发了A的解析，那么写入是就要比较版本，通过B解析A和A自身触发的版本比较，谁新写谁的
- 暂时不做，状态机制复杂

时序
- bufnr触发pc
- uri 获取 context 版本

set_timeinterval(1000, function()
    if not cache.busy then
        uri = pop(waiting)
        async(uri)
    end
end)

get_prompt(buf)
    uri = vim.uri_from_bufnr(buf)
    current_version = vim.api.nvim_buf_get_changedtick(buf)
    cache.dependencies[uri]
    cache.context[uri]
    if is_ok(cache.version[uri], current_version) or cache.busy then
        return cache.prompt[uri] or cache.prompt[uri] = merge_prompt(cache.context[uri], foreach(cache.dependencies[uri], function(def) return cache.context[def.uri] end))
    end
    if not cache.busy then
        async()
            cache.busy = true
            working = {}
            working.version = current_version
            working.dependencies[uri] = {}
            working.context[uri] = {}
            local current_definitions = ts_filter(buf)
            working.dependencies[uri] = current_definitions
            foreach(current_definitions, function(def) working.context[def.uri] = lsp_request('documentSymbol', def.uri) end)
            // when all done, update cache by merging working
            cache.dependencies[uri] = working.dependencies[uri]
            cache.context[uri] = working.context[uri]
            cache.version[uri] = current_version
            cache.busy = false
        end
    else
        waiting[uri] = true
    end
    return ''
end

]]

local Config = require('fittencode.config')
local Promise = require('fittencode.fn.promise')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Fn = require('fittencode.fn.core')
local Treesitter = require('fittencode.inline.pc.treesitter')
local Lsp = require('fittencode.inline.pc.lsp')
local UniqueQueue = require('fittencode.fn.unique_queue')
local Log = require('fittencode.log')

local M = {}

-- local filter_kinds = { 'Class', 'Function', 'Method' }
local filter_kinds = {}

local cache = {
    busy = { ctx = false, dep = false },
    dependencies = {},
    context = {},
    version = {
        main = {},
        context = {},
    },
}

local waiting = {
    queue_ctx = UniqueQueue.new(),
    queue_dep = UniqueQueue.new(),
}

local function is_ok(old_version, new_version)
    return math.abs(old_version - new_version) <= 10
end

local function stringfy(content)
    return vim.json.encode(content)
end

local function merge_prompt(context, dependencies, uri)
    local prompt = {}
    prompt[#prompt + 1] = '# Main Context'
    prompt[#prompt + 1] = '```json'
    prompt[#prompt + 1] = stringfy(context[uri] or {})
    prompt[#prompt + 1] = '```'
    prompt[#prompt + 1] = ''
    prompt[#prompt + 1] = '# Dependencies Context'
    vim.iter(dependencies[uri]):map(function(dep_uri)
        prompt[#prompt + 1] = '## Dependency: ' .. dep_uri
        prompt[#prompt + 1] = '```json'
        prompt[#prompt + 1] = stringfy(context[dep_uri] or {})
        prompt[#prompt + 1] = '```'
    end)
    return table.concat(prompt, '\n')
end

function M.get_prompt(bufnr)
    return Promise.new(function(resolve, reject)
        if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
            return reject({ _msg = 'Invalid buffer handle' })
        end

        local uri = vim.uri_from_bufnr(bufnr)
        local current_version = vim.api.nvim_buf_get_changedtick(bufnr)

        if cache.version.main[uri] and is_ok(cache.version.main[uri], current_version) then
            -- 这里返回的仅仅是尽可能多的数据，可能有些依赖来不及解析
            local prompt = merge_prompt(cache.context, cache.dependencies, uri)
            return resolve({ prompt = prompt, type = M.get_chosen_fast() })
        end
        cache.version.main[uri] = current_version

        waiting.queue_dep:push(uri)
        return reject({ _msg = 'Waiting for analysis' })
    end)
end

--[[

textDocument/definition

interface Location {
	uri: DocumentUri;
	range: Range;
}

]]
---@return FittenCode.Promise
local function lsp_request_definition(bufnr, pos)
    -- vim.lsp.buf_request_all
    ---@type vim.lsp.Client
    local lsp_client = vim.tbl_filter(
        function(client)
            return client:supports_method('textDocument/definition')
        end,
        vim.lsp.get_clients({ bufnr = bufnr })
    )[1]
    local params = Lsp.make_position_params(bufnr, pos)
    return Promise.new(function(resolve, reject)
        lsp_client:request('textDocument/definition', params, function(err, result)
            if err or not result then
                reject()
            else
                local uri = result.uri or result.targetUri
                for _, location in ipairs(result) do
                    if location.uri then -- Location
                        uri = location.uri
                    end
                    if location.targetUri then
                        uri = location.targetUri
                    end
                end
                if uri then
                    resolve(uri)
                else
                    reject()
                end
            end
        end, bufnr)
    end)
end

local last_client_id = nil

--[[

textDocument/documentSymbo

DocumentSymbol[]
interface DocumentSymbol {
    name: string;
    detail?: string;
    kind: SymbolKind;
    deprecated?: boolean;
    children?: DocumentSymbol[];

]]
---@return FittenCode.Promise
local function lsp_request_documentsymbol(bufnr)
    -- vim.lsp.buf_request_all
    ---@type vim.lsp.Client
    local lsp_clients = vim.tbl_filter(
        function(client)
            return client:supports_method('textDocument/documentSymbol')
        end,
        vim.lsp.get_clients({ bufnr = bufnr })
    )
    local lsp_client = lsp_clients[1]
    if lsp_client then
        last_client_id = lsp_client.id
    else
        assert(last_client_id)
        local attched = vim.lsp.buf_attach_client(bufnr, last_client_id)
    end
    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    return Promise.new(function(resolve, reject)
        lsp_client:request('textDocument/documentSymbol', params, function(err, result)
            if err or not result then
                reject()
            else
                resolve(result)
            end
        end, bufnr)
    end)
end

local function loop_dep()
    if cache.busy.dep or waiting.queue_dep:is_empty() then
        return
    end
    cache.busy.dep = true
    local uri = waiting.queue_dep:pop()
    assert(uri)
    local bufnr = vim.uri_to_bufnr(uri)

    Treesitter.fetch_symbols(bufnr):forward(function(symbols)
        if #symbols == 0 then
            return Promise.rejected()
        end
        local req = {}
        for _, symbol in ipairs(symbols) do
            local promise = Promise.new(function(resolve, reject)
                local pos = { symbol.range.lnum, symbol.range.col }
                lsp_request_definition(bufnr, pos):forward(function(dep_uri)
                    resolve(dep_uri)
                end):catch(function(_)
                    reject()
                end)
            end)
            req[#req + 1] = promise
        end
        return Promise.collect(req)
    end):forward(function(_)
        local dep_uris = _.resolved
        local dependencies = {}
        vim.iter(dep_uris):map(function(v)
            dependencies[#dependencies + 1] = v
        end)
        waiting.queue_ctx:push(uri)
        vim.iter(dependencies):filter(function(v)
            return v ~= uri
        end):map(function(v)
            waiting.queue_ctx:push(v)
        end)
        cache.dependencies[uri] = dependencies
    end):finally(function()
        cache.busy.dep = false
    end)
end

local function symbols_to_items(symbols, bufnr, position_encoding)
    local items = {}
    for _, symbol in ipairs(symbols) do
        --- @type string?, lsp.Range?
        local filename, range
        if symbol.location then
            --- @cast symbol lsp.SymbolInformation
            filename = vim.uri_to_fname(symbol.location.uri)
            range = symbol.location.range
        elseif symbol.selectionRange then
            --- @cast symbol lsp.DocumentSymbol
            filename = vim.api.nvim_buf_get_name(bufnr)
            range = symbol.selectionRange
        end
        local item = {}
        if filename and range then
            local kind = vim.lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
            if #filter_kinds > 0 and not vim.tbl_contains(filter_kinds, kind) then
                goto continue
            end
            local is_deprecated = symbol.deprecated
                or (symbol.tags and vim.tbl_contains(symbol.tags, vim.lsp.protocol.SymbolTag.Deprecated))
            local text = string.format(
                '[%s] %s%s%s',
                kind,
                symbol.name,
                symbol.containerName and ' in ' .. symbol.containerName or '',
                is_deprecated and ' (deprecated)' or ''
            )
            item = {
                -- filename = filename,
                kind = kind,
                text = text,
                detail = symbol.detail or '',
                -- children = {}
            }
        end
        if symbol.children then
            item.children = symbols_to_items(symbol.children, bufnr, position_encoding)
        end
        items[#items + 1] = item
        ::continue::
    end
    return items
end

local function loop_ctx()
    if cache.busy.ctx or waiting.queue_ctx:is_empty() then
        return
    end
    cache.busy.ctx = true
    local uri = waiting.queue_ctx:pop()
    assert(uri)

    -- ?
    local bufnr = vim.uri_to_bufnr(uri)
    local current_version = vim.api.nvim_buf_get_changedtick(bufnr)
    if cache.version.context[uri] and is_ok(cache.version.context[uri], current_version) then
        cache.busy.ctx = false
        return
    end
    -- LSP 附加需要 bufloaded
    vim.fn.bufload(bufnr)

    lsp_request_documentsymbol(bufnr):forward(function(symbols)
        local position_encoding = assert(vim.lsp.get_clients({ bufnr = bufnr })[1]).offset_encoding
        local items = symbols_to_items(symbols, bufnr, position_encoding)
        cache.context[uri] = items
        cache.version.context[uri] = current_version
    end):finally(function()
        cache.busy.ctx = false
    end)
end

--[[

- 5 是一种 Old
- 不等于5 是新的
    - 3 格式不一样

]]
M.last_chosen_prompt_type = '0'

function M.get_chosen_fast()
    return M.last_chosen_prompt_type
end

local _initialized = false

function M.init()
    if Config.use_project_completion.open == 'off' then
        return
    end
    if _initialized then
        return
    end
    vim.api.nvim_create_autocmd({ 'BufEnter', 'LspAttach' }, {
        group = vim.api.nvim_create_augroup('FittenCode.Inline.ProjectCompletion.CheckAuth', { clear = true }),
        pattern = '*',
        callback = function()
            M.update_chosen()
        end,
    })
    Fn.set_interval(40, function()
        Fn.schedule_call(loop_dep)
        Fn.schedule_call(loop_ctx)
    end)
    _initialized = true
end

---@type FittenCode.HTTP.Request?
local pc_check_auth_request = nil

function M.update_chosen()
    if pc_check_auth_request then
        pc_check_auth_request:abort()
    end
    local request = Client.make_request_auth(Protocol.Methods.pc_check_auth)
    if not request then
        return Promise.rejected({
            message = 'Failed to make pc_check_auth request',
        })
    end
    pc_check_auth_request = request
    ---@param _ FittenCode.HTTP.Request.Stream.EndEvent
    return request:async():forward(function(_)
        ---@type FittenCode.Protocol.Methods.PCCheckAuth.Response
        local response = _.text()
        if response and Fn.startswith(response, 'yes-') then
            local type = response:sub(5, 6)
            if #type == 0 then
                type = '0'
            end
            M.last_chosen_prompt_type = type
            return Promise.resolved(type)
        end
        return Promise.rejected({ message = 'Invalid response from server' })
    end)
end

function M.check_project_completion_available(buf)
    local mode = Config.use_project_completion.open

    local pc_check = M.get_chosen_fast()
    local has_ts = Treesitter.is_supported(buf)
    local has_lsp = #vim.lsp.get_clients({ bufnr = buf }) > 0

    local enable = false;
    if mode == 'on' then
        enable = has_ts and has_lsp;
    elseif mode == 'auto' then
        enable = (pc_check >= 1) and has_ts and has_lsp;
    elseif mode == 'off' then
        enable = false;
    end

    return enable;
end

function M.set_filter_kinds(kinds)
    filter_kinds = vim.deepcopy(kinds)
end

return M
