local Config = require('fittencode.config')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.functional.fn')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local Protocal = require('fittencode.client.protocol')

local ProjectCompletionService = {}

function ProjectCompletionService:new(options)
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

    self.request_handle = nil
    self.heart = 1
end

---@return string
function ProjectCompletionService:get_last_chosen_prompt_type()
    return self.project_completion.last_chosen_prompt_type
end

function ProjectCompletionService:abort_request()
    if self.request_handle then
        self.request_handle.abort()
        self.request_handle = nil
    end
end

---@return FittenCode.Concurrency.Promise
function ProjectCompletionService:get_project_completion_chosen()
    self:abort_request()
    local handle = Client.request(Protocal.Methods.pc_check_auth)
    if not handle then
        return Promise.reject()
    end
    self.request_handle = handle
    return handle.promise():forward(function(_)
        local response = _.text()
        if Fn.startswith(response, 'yes-') then
            local u = response:split('-')[1] or '0'
            local ty = tonumber(u:sub(1, 1))
            return ty
        else
            return Promise.reject()
        end
    end)
end

-- 检测是否可使用 Project Completion
-- * resolve 代表可以
-- * reject 代表不可用或者未知出错
---@param lsp number
---@return FittenCode.Concurrency.Promise
function ProjectCompletionService:check_project_completion_available(lsp)
    local _is_available = function(chosen)
        local open = Config.use_project_completion.open
        local available = false
        if open == 'auto' then
            if chosen >= 1 and lsp == 1 and self.heart ~= 2 then
                available = true
            end
        elseif open == 'on' then
            if lsp == 1 and self.heart ~= 2 then
                available = true
            end
        elseif open == 'off' then
            available = false
        end
        return available
    end
    return self:get_project_completion_chosen():forward(function(chosen)
        if _is_available(chosen) then
            return chosen
        else
            return Promise.reject()
        end
    end)
end

return ProjectCompletionService
