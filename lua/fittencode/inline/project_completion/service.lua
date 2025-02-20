local Config = require('fittencode.config')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.functional.fn')
local Client = require('fittencode.client')
local Log = require('fittencode.log')
local Protocal = require('fittencode.client.protocol')
local HeartBeater = require('fittencode.inline.project_completion.heart_beater')
local LspService = require('fittencode.functional.lsp_service')
local Perf = require('fittencode.functional.performance')

local Service = {}

function Service.new(options)
    local obj = {}
    setmetatable(obj, { __index = Service })
    obj:__initialize(options)
    return obj
end

function Service:__initialize(options)
    options = options or {}
    self.provider = options.provider or 'semantic_context'
    local ProjectCompletion = require('fittencode.inline.project_completion.versions.' .. self.provider)
    self.project_completion = ProjectCompletion.new({
        get_chosen = function() return self:get_chosen() end,
    })
    self.request_handles = {}
    self.last_chosen_prompt_type = '0'
end

---@return string
function Service:get_last_chosen_prompt_type()
    return self.last_chosen_prompt_type
end

function Service:abort_request()
    for _, handle in pairs(self.request_handles or {}) do
        handle.abort()
    end
    self.request_handles = {}
end

function Service:push_request_handle(handle)
    self.request_handles[#self.request_handles + 1] = handle
end

function Service:generate_prompt(buf, position)
    return self.project_completion:generate_prompt(buf, position)
end

---@return FittenCode.Concurrency.Promise
function Service:get_chosen()
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
            self.last_chosen_prompt_type = _ and ty or '0'
            return self.last_chosen_prompt_type
        end
        return Promise.reject()
    end)
end

return Service
