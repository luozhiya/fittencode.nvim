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
local Treesitter = require('fittencode.pi.treesitter')
local ProjectInsight = require('fittencode.pi')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Fn = require('fittencode.fn.core')

local M = {}

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
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return Promise.rejected({ _msg = 'Invalid buffer handle' })
    end
    local uri = vim.uri_from_bufnr(bufnr)
    return ProjectInsight.request_fast(uri):forward(function(result)
        local prompt = merge_prompt(result.context, result.dependencies, uri)
        return Promise.resolved({ prompt = prompt, type = M.get_chosen_fast() })
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
            _msg = 'Failed to make pc_check_auth request',
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
        return Promise.rejected({ _msg = 'Invalid response from server' })
    end)
end

function M.check_project_completion_available(buf)
    local mode = Config.use_project_completion.open

    local pc_check = tonumber(M.get_chosen_fast()) or 0
    local has_ts_dep = Treesitter.is_supported(buf, 'dep')
    local has_lsp = #vim.lsp.get_clients({ bufnr = buf }) > 0
    local env_ok = has_ts_dep and has_lsp

    local enable = false;
    if mode == 'on' then
        enable = env_ok;
    elseif mode == 'auto' then
        enable = (pc_check >= 1) and env_ok;
    elseif mode == 'off' then
        enable = false;
    end

    return enable;
end

return M
