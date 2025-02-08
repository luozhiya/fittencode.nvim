local Config = require('fittencode.config')
local ProjectCompletionFactory = require('fittencode.inline.project_completion')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local Protocal = require('fittencode.client.protocol')

---@class FittenCode.Inline.ProjectCompletionService
local ProjectCompletionService = {}

---@return FittenCode.Inline.ProjectCompletionService
function ProjectCompletionService:new(options)
    ---@class FittenCode.Inline.ProjectCompletionService
    local obj = {}
    setmetatable(obj, { __index = ProjectCompletionService })
    obj:__initialize(options)
    return obj
end

function ProjectCompletionService:__initialize(options)
    self.project_completion = {
        v1 = assert(ProjectCompletionFactory.create('v1')),
        v2 = assert(ProjectCompletionFactory.create('v2')),
    }
    self.last_chosen_prompt_type = '0'
    self.request_handle = nil
end

---@return string
function ProjectCompletionService:get_last_chosen_prompt_type()
    return self.last_chosen_prompt_type
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
            local ty = u:sub(1, 1)
            self.last_chosen_prompt_type = ty
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
        local heart = 1
        local available = false
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
    return self:get_project_completion_chosen():forward(function(chosen)
        if _is_available(chosen) then
            return chosen
        else
            return Promise.reject()
        end
    end)
end

return ProjectCompletionService
