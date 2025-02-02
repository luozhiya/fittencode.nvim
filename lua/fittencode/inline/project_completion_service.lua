local Config = require('fittencode.config')
local ProjectCompletionFactory = require('fittencode.inline.project_completion')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local Protocal = require('fittencode.client.protocol')

---@class FittenCode.Inline.ProjectCompletionService
local ProjectCompletionService = {}

---@class FittenCode.Inline.ProjectCompletionService.Options

---@param options? FittenCode.Inline.ProjectCompletionService.Options
---@return FittenCode.Inline.ProjectCompletionService
function ProjectCompletionService:new(options)
    ---@class FittenCode.Inline.ProjectCompletionService
    local obj = {}
    setmetatable(obj, { __index = ProjectCompletionService })
    obj:__initialize(options)
    return obj
end

---@param options? FittenCode.Inline.ProjectCompletionService.Options
function ProjectCompletionService:__initialize(options)
    self.project_completion = {
        v1 = assert(ProjectCompletionFactory.create('v1')),
        v2 = assert(ProjectCompletionFactory.create('v2')),
    }
    self.last_chosen_prompt_type = '0'
end

---@return string
function ProjectCompletionService:get_last_chosen_prompt_type()
    return self.last_chosen_prompt_type
end

---@class FittenCode.Inline.ProjectCompletionService.GetProjectCompletionChosen.Options : FittenCode.AsyncResultCallbacks

---@param options FittenCode.Inline.ProjectCompletionService.GetProjectCompletionChosen.Options
function ProjectCompletionService:get_project_completion_chosen(options)
    Promise.new(function(resolve, reject)
        Client.request(Protocal.Methods.pc_check_auth, {
            on_once = function(stdout)
                if Fn.startswith(stdout, 'yes-') then
                    local u = stdout:split('-')[1] or '0'
                    self.last_chosen_prompt_type = u:sub(1, 1)
                    Fn.schedule_call(options.on_success, self.last_chosen_prompt_type)
                else
                    reject()
                end
            end,
            on_error = function()
                reject()
            end
        })
    end):catch(function()
        Fn.schedule_call(options.on_failure)
    end)
end

---@class FittenCode.Inline.ProjectCompletionService.CheckProjectCompletionAvailable.Options : FittenCode.AsyncResultCallbacks

---@param lsp number
---@param options FittenCode.Inline.ProjectCompletionService.CheckProjectCompletionAvailable.Options
function ProjectCompletionService:check_project_completion_available(lsp, options)
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
    Promise.new(function(resolve, reject)
        self:get_project_completion_chosen({
            on_success = function(chosen)
                if _is_available(chosen) then
                    Fn.schedule_call(options.on_success)
                else
                    reject()
                end
            end,
            on_failure = function()
                reject()
            end,
        })
    end):catch(function()
        Fn.schedule_call(options.on_failure)
    end)
end

return ProjectCompletionService
