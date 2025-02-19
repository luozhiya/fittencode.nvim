local Config = require('fittencode.config')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.functional.fn')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local Protocal = require('fittencode.client.protocol')
local HeartBeater = require('fittencode.inline.project_completion.heart_beater')
local LspService = require('fittencode.functional.lsp_service')
local Perf = require('fittencode.functional.performance')

local ProjectCompletionService = {}

function ProjectCompletionService.new(options)
    local obj = {}
    setmetatable(obj, { __index = ProjectCompletionService })
    obj:__initialize(options)
    return obj
end

function ProjectCompletionService:__initialize(options)
    options = options or {}
    self.provider = options.provider or 'semantic_context'
    if self.provider == 'vscode' then
        self.project_completion = require('fittencode.inline.project_completion.versions.vscode').new()
    elseif self.provider == 'semantic_context' then
        self.project_completion = require('fittencode.inline.project_completion.versions.semantic_context').new()
    end
    self.heart_beater = HeartBeater.new()
    self.request_handles = {}
    self.last_chosen_prompt_type = '0'
end

---@return string
function ProjectCompletionService:get_last_chosen_prompt_type()
    return self.last_chosen_prompt_type
end

function ProjectCompletionService:abort_request()
    for _, handle in pairs(self.request_handles or {}) do
        handle.abort()
    end
    self.request_handles = {}
end

function ProjectCompletionService:push_request_handle(handle)
    self.request_handles[#self.request_handles + 1] = handle
end

-- 检测 LSP 客户端是否支持 `textDocument/documentSymbol`
-- * 1  代表可用
-- * 0  代表不可用
-- * -1 代表没有 LSP 客户端
function ProjectCompletionService:get_file_lsp(buf)
    if not LspService.has_lsp_client(buf) then
        return -1
    end
    if LspService.supports_method('textDocument/documentSymbol', buf) then
        return 1
    end
    return 0
end

function ProjectCompletionService:generate_prompt(buf, position)
    return self.project_completion:generate_prompt(buf, position)
end

---@return FittenCode.Concurrency.Promise
function ProjectCompletionService:get_chosen()
    -- 0. 清理过期请求
    self:abort_request()
    -- 1. 非标准版
    if Config.server.fitten_version ~= 'default' then
        self.last_chosen_prompt_type = '2'
        return Promise.resolve(self.last_chosen_prompt_type)
    end
    -- 2. 缓存值
    if Perf.tok(self.last_chosen_time) < 1e3 * 10 then
        return Promise.resolve(self.last_chosen_prompt_type)
    end
    -- 3. 发送请求
    local handle = Client.request(Protocal.Methods.pc_check_auth)
    if not handle then
        return Promise.reject()
    end
    self:push_request_handle(handle)
    return handle.promise():forward(function(_)
        local response = _.text()
        -- 只要是前缀为 `yes-` 的字符串，就认为是合法的
        if Fn.startswith(response, 'yes-') then
            self.last_chosen_time = Perf.tick()
            local _, ty = pcall(function()
                return (response:split('-')[1] or '0'):sub(1, 1)
            end)
            if _ then
                self.last_chosen_prompt_type = ty
            else
                self.last_chosen_prompt_type = '0'
            end
            return self.last_chosen_prompt_type
        end
        return Promise.reject()
    end)
end

-- 检测是否可使用 Project Completion
-- * resolve 代表可以
-- * reject 代表不可用或者未知出错
---@param lsp number
---@return FittenCode.Concurrency.Promise
function ProjectCompletionService:check_available(lsp)
    local _is_available = function(chosen)
        chosen = tonumber(chosen)
        local open = Config.use_project_completion.open
        local available = false
        local heart = self.heart_beater:get_status()
        if open == 'auto' then
            if chosen >= 1 and lsp == 1 and heart ~= 2 then
                available = true
            end
        elseif open == 'on' then
            if lsp == 1 and heart ~= 2 then
                available = true
            end
        elseif open == 'off' then
            available = false
        end
        return available
    end
    return self:get_chosen():forward(function(chosen)
        if _is_available(chosen) then
            return chosen
        else
            return Promise.reject()
        end
    end)
end

return ProjectCompletionService
