local Promise = require('fittencode.concurrency.promise')
local Log = require('fittencode.log')
local Config = require('fittencode.config')
local Perf = require('fittencode.functional.performance')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local URLSearchParams = require('fittencode.net.fn.url_search_params')

-- ms
local SENDING_GAP = 1e3 * 60 * 10

---@class FittenCode.Inline.GrayTestHelper
local GrayTestHelper = {}

---@class FittenCode.Inline.GrayTestHelper.Plan
local Plan = {}

function Plan.new(name, online_result, enterprise_result)
    local self = setmetatable({
        name = name,
        online_result = online_result,
        enterprise_result = enterprise_result
    }, { __index = Plan })
    return self
end

local PLANS = {
    Plan.new('edit_mode_auto', nil, 1),
    Plan.new('write_mode_beta', nil, 1)
}

---@class FittenCode.Inline.GrayTestHelper.GrayStatus
---@field last_user_id string
---@field last_request_time number
---@field last_result number
local GrayStatus = {}

function GrayStatus.new(last_user_id, last_request_time, last_result)
    local self = setmetatable({
        last_user_id = last_user_id or '',
        last_request_time = last_request_time or 0,
        last_result = last_result or 0
    }, { __index = GrayStatus })
    return self
end

---@type table<string, FittenCode.Inline.GrayTestHelper.GrayStatus>
local gray_status_dict = {}

function GrayTestHelper.init()
    gray_status_dict = {}
    for _, plan in ipairs(PLANS) do
        gray_status_dict[plan.name] = GrayStatus.new()
    end
end

function GrayTestHelper.destroy()
    gray_status_dict = {}
end

---@return FittenCode.Concurrency.Promise
function GrayTestHelper.send_requests(user_id, plan_name)
    local request = Client.make_request(Protocol.Methods.gray_test, {
        variables = {
            plan_name = plan_name,
        }
    })
    if not request then
        Log.error('Gray test request failed')
        return Promise.reject()
    end
    return request:async():forward(function(response)
        return tonumber(response.text())
    end)
end

---@return FittenCode.Concurrency.Promise
function GrayTestHelper.update_result(user_id, plan_name)
    return GrayTestHelper.send_requests(user_id, plan_name):forward(function(result)
        local gray_status = gray_status_dict[plan_name]
        gray_status.last_user_id = user_id
        gray_status.last_request_time = Perf.tick()
        gray_status.last_result = result
        return vim.deepcopy(gray_status)
    end)
end

---@return FittenCode.Concurrency.Promise
function GrayTestHelper.get_result(user_id, plan_name)
    local plan = PLANS[plan_name]
    if not plan then
        Log.error('Gray plan {} not found', plan_name)
        return Promise.reject()
    end
    if Config.server.fitten_version ~= 'default' then
        if plan.enterprise_result then
            return Promise.resolve(plan.enterprise_result)
        end
    elseif plan.online_result then
        return Promise.resolve(plan.online_result)
    end
    local gray_status = gray_status_dict[plan_name]
    if gray_status.last_user_id == user_id and Perf.tok(gray_status.last_request_time) < SENDING_GAP then
        return Promise.resolve(gray_status.last_result)
    else
        return GrayTestHelper.update_result(user_id, plan_name):forward(function(status)
            return status.last_result
        end)
    end
end

---@return FittenCode.Concurrency.Promise
function GrayTestHelper.get_all_results(user_id)
    local promises = {}
    for _, plan in ipairs(PLANS) do
        promises[#promises + 1] = GrayTestHelper.get_result(user_id, plan.name)
    end
    return Promise.all(promises)
end

return GrayTestHelper
