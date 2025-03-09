local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local URLSearchParams = require('fittencode.net.url_search_params')
local Config = require('fittencode.config')
local GrayTestHelper = require('fittencode.inline.gray_test_helper')
local EventLoop = require('fittencode.vim.promisify.uv.event_loop')
local Fn = require('fittencode.functional.fn')
local Tracker = require('fittencode.services.tracker')
local Extension = require('fittencode.extension')
local Log = require('fittencode.log')

-- ms
local STATISTIC_SENDING_GAP = 1e3 * 60 * 10

--[[

StatisticRecord
- 单个 uri 的统计数据

]]
local StatisticRecord = {}

-- 修改后的 __index 元方法，优先检查类方法，再检查 _data 字段
StatisticRecord.__index = function(self, key)
    -- 先检查类中是否存在该方法或字段（如 reset）
    local class_value = StatisticRecord[key]
    if class_value ~= nil then
        return class_value
    end
    -- 若类中没有，则从 _data 中获取数据字段
    return rawget(self._data, key)
end

-- 新增的 __newindex 方法（写入时触发）
StatisticRecord.__newindex = function(self, key, value)
    -- 将赋值操作重定向到 _data 表中
    rawset(self._data, key, value)
end

function StatisticRecord.new()
    local self = {
        _data = {
            -- VSCode standard
            accept_cnt = 0,                            -- 总的采纳次数
            insert_with_completion_cnt = 0,            -- 采纳的总字符数
            completion_times = 0,                      -- 补全的总次数
            completion_total_time = 0,                 -- 补全的总时间
            is_pc_cnt = 0,                             -- Project Completion 的次数
            edit_show_cnt = 0,                         -- Edit Completion 的次数
            edit_cancel_cnt = 0,                       -- Edit Completion 的取消次数
            edit_accept_cnt = 0,                       -- Edit Completion 的采纳次数
            edit_change_config = 0,                    -- Edit Completion 的配置
            -- Neovim only
            accept_all_completion_suggestions_cnt = 0, -- 采纳所有建议的次数
            completion_suggestions_cnt = 0             -- 补全的总字符数
        }
    }
    setmetatable(self, StatisticRecord)
    return self
end

function StatisticRecord:reset()
    local r = StatisticRecord.new()
    self._data = r._data
end

function StatisticRecord:raw()
    return vim.deepcopy(self._data)
end

local CompletionRecord = {}

-- 修改后的 __index 元方法，优先检查类方法，再检查 _data 字段
CompletionRecord.__index = function(self, key)
    -- 先检查类中是否存在该方法或字段（如 merge）
    local class_value = CompletionRecord[key]
    if class_value ~= nil then
        return class_value
    end
    -- 若类中没有，则从 _data 中获取数据字段
    return rawget(self._data, key)
end

-- 新增的 __newindex 方法（写入时触发）
CompletionRecord.__newindex = function(self, key, value)
    -- 将赋值操作重定向到 _data 表中
    rawset(self._data, key, value)
end

function CompletionRecord.from_statitics_record(record, specific_record)
    local self = {
        _data = vim.tbl_deep_extend('force', specific_record or {
            user_id = '',
            has_lsp = false,
            enabled = 'auto',
            tag = {},
            chosen = 0,
            use_project_completion = 0,
            uri = '',
        }, record._data)
    }
    setmetatable(self, CompletionRecord)
    return self
end

function CompletionRecord:reset()
    local r = CompletionRecord.new()
    self._data = r._data
end

function CompletionRecord:merge(other)
    if not other then
        return
    end
    if self.uri ~= other.uri then
        return
    end
    -- 累加数据
    local accumulatable_fields = {
        'accept_cnt',
        'insert_with_completion_cnt',
        'completion_times',
        'completion_total_time',
        'is_pc_cnt',
        'edit_show_cnt',
        'edit_cancel_cnt',
        'edit_accept_cnt',
        'accept_all_completion_suggestions_cnt',
        'completion_suggestions_cnt'
    }
    for _, field in ipairs(accumulatable_fields) do
        self._data[field] = self._data[field] + (other._data[field] or 0)
    end
end

function CompletionRecord:raw()
    return vim.deepcopy(self._data)
end

--[[

CompletionStatistics
- 通过监听 Inline 的事件，非侵入式地记录用户的输入行为
- 和 VSCode 版本的不一致的地方：
  - 在 Neovim 中只统计在存在补全的情况下的输入行为
- 统计数据：
  - 对补全的接纳字符数 insert_with_completion_cnt
  - 补全的总次数 completion_times
  - 补全的总时间 completion_total_time
  - 补全的总字符数 completion_suggestions_cnt
  - 采纳的总次数 accept_cnt
  - 采纳所有补全建议的次数 accept_all_completion_suggestions_cnt
]]
local CompletionStatistics = {}
CompletionStatistics.__index = CompletionStatistics

function CompletionStatistics.new(options)
    local self = {}
    setmetatable(self, CompletionStatistics)
    self:_initialize(options)
    return self
end

function CompletionStatistics:_initialize(options)
    options = options or {}
    self.statistic_dict = options.statistic_dict or {}
    self.get_chosen = options.get_chosen
    self:_set_global_statistic()
    self:_set_document_change_handler()
    self.timer = EventLoop.set_interval(STATISTIC_SENDING_GAP, Fn.schedule_call_wrap_fn(function() self:send_status() end))
end

function CompletionStatistics:_set_global_statistic()
    self.statistic_dict['global'] = StatisticRecord.new()
    local open = Config.use_project_completion.open
    if open == 'auto' then
        self.statistic_dict['global'].edit_change_config = 1
    elseif open == 'on' then
        self.statistic_dict['global'].edit_change_config = 2
    elseif open == 'off' then
        self.statistic_dict['global'].edit_change_config = 3
    end
end

--[[

CompletionStatistics:_set_inline_event_handler
- 触发时，可以记录 completion_times 数据
- 根据返回的数据时间，可以记录 completion_total_time 数据
- 当 inline session 结束时，可以记录 accept_cnt/accept_all_suggestion_cnt/suggestion_chars_total_cnt/accept_chars_total_cnt 数据

InlineController.register_observer({
    id = 'completion_statistics',
    event = '*',
    callback = function(payload)
        self:_set_inline_event_handler(payload)
    end
})

]]
function CompletionStatistics:_set_inline_event_handler(payload)
    local event = payload.event
    local data = payload.data

    local uri = data.uri
    if not self.statistic_dict[uri] then
        self.statistic_dict[uri] = StatisticRecord.new()
    end
    local uri_stats = self.statistic_dict[uri]

    if event == 'Completion.Requested' then
        uri_stats.completion_times = uri_stats.completion_times + 1
    elseif event == 'Completion.Received' then
        local time = data.time
        uri_stats.completion_total_time = uri_stats.completion_total_time + time
        local suggestions = data.suggestions
        if suggestions then
            uri_stats.completion_suggestions_cnt = uri_stats.completion_suggestions_cnt + #suggestions
        end
    elseif event == 'Completion.Completed' then
        local accept = data.accept
        local suggestions = data.suggestions
        if suggestions and accept and accept ~= '' then
            if accept == suggestions then
                uri_stats.accept_all_completion_suggestions_cnt = uri_stats.accept_all_completion_suggestions_cnt + 1
            end
            uri_stats.accept_cnt = uri_stats.accept_cnt + 1
            uri_stats.insert_with_completion_cnt = uri_stats.insert_with_completion_cnt + #accept
        end
    end
end

function CompletionStatistics:update_edit_mode_status(uri, action)
    if not uri or not action then
        Log.error('Error: uri and action must be provided.')
        return
    end

    if not self.statistic_dict[uri] then
        self.statistic_dict[uri] = StatisticRecord.new()
    end

    local uri_stats = self.statistic_dict[uri]
    local action_to_counter = {
        show = 'edit_show_cnt',
        cancel = 'edit_cancel_cnt',
        accept = 'edit_accept_cnt'
    }

    local counter = action_to_counter[action]
    if counter then
        uri_stats[counter] = uri_stats[counter] + 1
    else
        Log.warn("Warning: Unrecognized action '" .. action .. "' for uri '" .. uri .. "'.")
    end
end

function CompletionStatistics:update_completion_time(uri, time, is_pc)
    if not uri or not time then
        Log.error('Error: uri and time must be provided.')
        return
    end

    if not self.statistic_dict[uri] then
        self.statistic_dict[uri] = StatisticRecord.new()
    end

    local uri_stats = self.statistic_dict[uri]

    if is_pc == nil then
        Log.warn('Warning: is_pc is not provided. Defaulting to false.')
        is_pc = false
    end

    if is_pc then
        uri_stats.is_pc_cnt = uri_stats.is_pc_cnt + 1
    else
        uri_stats.is_pc_cnt = uri_stats.is_pc_cnt - 1
    end

    uri_stats.completion_times = uri_stats.completion_times + 1
    uri_stats.completion_total_time = uri_stats.completion_total_time + time
end

function CompletionStatistics:send_one_status(completion_record)
    local function _to_query(data)
        local query = URLSearchParams.new()
        for k, v in pairs(data) do
            if type(v) == 'table' then
                query:append(k, vim.json.encode(v))
            else
                query:append(k, v)
            end
        end
        return query:to_string()
    end
    local status = _to_query(completion_record:raw())
    Client.request(Protocol.Methods.statistic_log, {
        variables = { completion_statistics = status }
    })
end

--[[

按日期分组，按 URI 分组，记录每个 URI 的统计数据。

两级索引：
- Date
- URI

]]
function CompletionStatistics:update_tracker(current)
    if not current or not current.uri then
        Log.error('current and current.uri must be provided.')
        return
    end

    Tracker.mut_completion(function(completion_tracker)
        local date = Fn.get_current_date()
        local rec = completion_tracker[date]

        if not rec then
            completion_tracker[date] = {}
            rec = completion_tracker[date]
        end

        if not rec[current.uri] then
            rec[current.uri] = current
        else
            rec[current.uri]:merge(current)
        end
    end)
end

function CompletionStatistics:send_status()
    local open = Config.use_project_completion.open
    local user_id = Client.get_api_key_manager():get_fitten_user_id()
    local chosen = self.get_chosen(self.user_id)

    for uri, stats in pairs(self.statistic_dict) do
        if self.completion_status_dict[uri] then
            local a = self.completion_status_dict[uri]
            if vim.uv.now() - a.sending_time > STATISTIC_SENDING_GAP then
                goto continue
            end
        end
        if stats.completion_times == 0 and stats.edit_show_cnt == 0 and stats.edit_cancel_cnt == 0 and stats.edit_accept_cnt == 0 and stats.edit_change_config == 0 then
            goto continue
        end

        local i = 0
        if uri == 'global' then
            i = 0
        else
            i = self.get_file_lsp(uri)
        end

        local completion_type = 0
        local last_chosen_prompt_type = 0
        local use_project_completion = 0

        local tag = {
            gray_status = GrayTestHelper.get_all_results(),
            chosen = chosen,
            is_pc = stats.is_pc_cnt > 0 and 1 or 0,
            completion_type = completion_type,
            pc_prompt_type = last_chosen_prompt_type,
            ide = Extension.ide_name
        }

        local completion_record = CompletionRecord.from_statitics_record(stats, {
            user_id = user_id,
            has_lsp = (i == 1),
            enabled = open,
            tag = tag,
            chosen = chosen,
            use_project_completion = use_project_completion,
            uri = uri,
        })

        self:update_tracker(completion_record)
        self:send_one_status(completion_record)
        stats:reset()

        ::continue::
    end
end

return CompletionStatistics
