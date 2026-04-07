-- Project Insight

local Config = require('fittencode.config')
local Promise = require('fittencode.fn.promise')
local Fn = require('fittencode.fn.core')
local Treesitter = require('fittencode.pi.treesitter')
local Lsp = require('fittencode.pi.lsp')
local UniqueQueue = require('fittencode.fn.unique_queue')
local Log = require('fittencode.log')
local Task = require('fittencode.pi.task')
local Perf = require('fittencode.fn.perf')

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

local working = {
    dep = nil,
    ctx = nil,
}

local function is_working(uri)
    return working.dep and working.dep == uri or working.ctx and working.ctx == uri
end

local function is_queued(uri)
    return waiting.queue_ctx:containsbykey(uri) or waiting.queue_dep:containsbykey(uri)
end

local function is_ok(old_version, new_version)
    return math.abs(old_version - new_version) <= 10
end

local lsp_config = {}

local function loop_dep()
    if cache.busy.dep or waiting.queue_dep:is_empty() then
        return
    end
    cache.busy.dep = true
    ---@type FittenCode.ProjectInsight.Task
    local task = assert(waiting.queue_dep:pop())
    local uri = task.uri

    working.dep = uri
    local bufnr = vim.uri_to_bufnr(uri)

    Treesitter.fetch_symbols(bufnr, 'dep'):forward(function(symbols)
        if #symbols == 0 then
            return Promise.rejected()
        end
        local req = {}
        for _, symbol in ipairs(symbols) do
            local promise = Promise.new(function(resolve, reject)
                local pos = { symbol.range.lnum, symbol.range.col }
                Lsp.lsp_request_definition(bufnr, pos):forward(function(dep_uri)
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
        local _ = Task.new(uri)
        task:add_child(_)
        waiting.queue_ctx:push(_)
        vim.iter(dependencies):filter(function(v)
            return v ~= uri
        end):map(function(v)
            local _ = Task.new(v)
            task:add_child(_)
            waiting.queue_ctx:push(_)
        end)
        cache.dependencies[uri] = dependencies
    end):finally(function()
        working.dep = nil
        cache.busy.dep = false
    end)
end

local function fallback_client(bufnr)
    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    Log.debug('fallback_client: ft = {}', ft)
    local client_cfg = lsp_config[ft]
    -- client_cfg.root_dir = nil
    local lsp_client = assert(vim.lsp.get_client_by_id(assert(vim.lsp.start(client_cfg, { bufnr = bufnr }))))
    return lsp_client
end

local function loop_ctx()
    if cache.busy.ctx or waiting.queue_ctx:is_empty() then
        return
    end
    cache.busy.ctx = true
    ---@type FittenCode.ProjectInsight.Task
    local task = assert(waiting.queue_ctx:pop())
    local uri = task.uri
    working.ctx = uri
    Log.debug('loop_ctx uri = {}', uri)

    -- ?
    local bufnr = vim.uri_to_bufnr(uri)
    local current_version = vim.api.nvim_buf_get_changedtick(bufnr)
    if cache.version.context[uri] and is_ok(cache.version.context[uri], current_version) then
        working.ctx = nil
        cache.busy.ctx = false
        task.state_machine:transition('completed')
        return
    end

    task.state_machine:transition('running')

    -- LSP 附加需要 bufloaded
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        vim.fn.bufload(bufnr)
    end

    Lsp.lsp_request_documentsymbol(bufnr, fallback_client):forward(function(symbols)
        local position_encoding = assert(vim.lsp.get_clients({ bufnr = bufnr })[1]).offset_encoding
        local items = Lsp.symbols_to_items(symbols, bufnr, position_encoding, filter_kinds)
        cache.context[uri] = items
        cache.version.context[uri] = current_version
    end):catch(function(err)
        Log.debug('loop_ctx: err = {}', err)
    end):finally(function()
        working.ctx = nil
        cache.busy.ctx = false
        task.state_machine:transition('completed')
    end)
end

local timer = nil
local function _try_init()
    if timer then
        return
    end
    timer = Fn.set_interval(40, function()
        Fn.schedule_call(loop_dep)
        Fn.schedule_call(loop_ctx)
    end)
end

---@param task FittenCode.ProjectInsight.Task
local function _request(task, fast)
    _try_init()
    return Promise.new(function(resolve, reject)
        local uri = task.uri
        local bufnr = vim.uri_to_bufnr(uri)
        local current_version = vim.api.nvim_buf_get_changedtick(bufnr)
        local ver_ok = cache.version.main[uri] and is_ok(cache.version.main[uri], current_version)

        if ver_ok or (not ver_ok and (is_working(uri) or is_queued(uri))) then
            Log.debug('_request: cache hit, uri = {}, ctx = {}, dep = {}', uri, cache.context, cache.dependencies)
            -- 这里返回的仅仅是尽可能多的数据，可能有些依赖来不及解析
            if fast then
                return resolve({ context = cache.context, dependencies = cache.dependencies, uri = uri })
            else
                return task.state_machine:transition('completed')
            end
        end
        -- 从当前 bufnr 触发的pc
        -- 可以认为该bufnr引用的都是同样类型的文件
        -- 对于后续动态load的buffer，可以使用同样的lsp config来初始化一个lsp client
        local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
        if not lsp_config[ft] then
            local lsp_client = Lsp.get_lsp_by_method(bufnr, 'textDocument/definition')
            assert(lsp_client)
            lsp_config[ft] = vim.deepcopy(lsp_client.config)
        end

        cache.version.main[uri] = current_version
        waiting.queue_dep:push(task)

        if fast then
            return reject({ _msg = 'Waiting for analysis' })
        end
    end)
end

function M.request_fast(uri)
    return _request(Task.new(uri), true)
end

-- 返回cache或者等待全部分析完成
function M.request(uri)
    return Promise.new(function(resolve, reject)
        local t = Task.new(uri)
        t.state_machine:subscribe(function(state)
            if state.to == 'completed' then
                local ms = Perf.tok(t.timestamp)
                Log.debug('request completed: uri = {}, time = {}ms', uri, ms)
                resolve({ context = cache.context, dependencies = cache.dependencies, uri = uri })
            end
        end)
        _request(t)
    end)
end

return M
