local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local URLSearchParams = require('fittencode.net.url_search_params')
local Config = require('fittencode.config')
local GrayTestHelper = require('fittencode.inline.gray_test_helper')
local EventLoop = require('fittencode.vim.promisify.uv.event_loop')
local Fn = require('fittencode.functional.fn')
local Tracker = require('fittencode.services.tracker')
local Extension = require('fittencode.extension')

local STATISTIC_SENDING_GAP = 1e3 * 60 * 10
local MAX_ACCEPT_LENGTH = 5

local Record = {}
Record.__index = Record

function Record.new()
    local self = {}
    setmetatable(self, Record)
    self:reset()
    return self
end

function Record:reset()
    -- VSCode standard
    self.delete_cnt = 0
    self.insert_without_paste_cnt = 0
    self.insert_cnt = 0
    self.accept_cnt = 0 -- 总的采纳次数
    self.insert_with_completion_without_paste_cnt = 0
    self.insert_with_completion_cnt = 0
    self.completion_times = 0 -- 补全的总次数
    self.completion_total_time = 0 -- 补全的总时间
    self.is_pc_cnt = 0 -- Project Completion 的次数
    self.edit_show_cnt = 0 -- Edit Completion 的次数
    self.edit_cancel_cnt = 0 -- Edit Completion 的取消次数
    self.edit_accept_cnt = 0 -- Edit Completion 的采纳次数
    self.edit_change_config = 0 -- Edit Completion 的配置
    -- Neovim only
    self.accept_all_suggestion_cnt = 0 -- 采纳所有建议的次数
    self.suggestion_chars_total_cnt = 0 -- 补全的总字符数
    self.accept_chars_total_cnt = 0 -- 采纳的总字符数
end

--[[

CompletionStatistics
- 通过监听 Inline 的事件，非侵入式地记录用户的输入行为
- 和 VSCode 版本的不一致的地方：
  - 在 Neovim 中只统计在存在补全的情况下的输入行为
- 统计数据：
  - 对补全的接纳字符数
  - 补全的总次数
  - 补全的总时间
  - 补全的总字符数
  - 采纳所有补全建议的次数
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
    self.completion_status_dict = options.completion_status_dict or {}
    self.statistic_dict = options.statistic_dict or {}
    self.user_id = options.user_id
    self.get_chosen = options.get_chosen
    self:_set_global_statistic()
    self:_set_document_change_handler()
    self.timer = EventLoop.set_interval(STATISTIC_SENDING_GAP, Fn.schedule_call_wrap_fn(function() self:send_status() end))
end

function CompletionStatistics:_set_global_statistic()
    self.statistic_dict['global'] = Record.new()
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
]]
function CompletionStatistics:_set_inline_event_handler(event)
end

function CompletionStatistics:_set_document_change_handler()
end

function CompletionStatistics:handle_text_document_change(s)
    local o = s.document
    local a = o.uri:toString()
    if self.completion_status_dict[a] then
        if not self.statistic_dict[a] then
            self.statistic_dict[a] = Record.new()
        end
        local entry = self.completion_status_dict[a]
        if (os.clock() * 1000 - entry.sending_time) > STATISTIC_SENDING_GAP then
            return
        end
        for _, l in ipairs(s.contentChanges) do
            local c = self:check_accept(o, entry, l.rangeOffset, l.text)
            local u = #l.text
            self.statistic_dict[a].insert_cnt = self.statistic_dict[a].insert_cnt + u
            if u <= MAX_ACCEPT_LENGTH or c == 1 then
                self.statistic_dict[a].insert_without_paste_cnt = self.statistic_dict[a].insert_without_paste_cnt + u
            end
            if c == 1 then
                self.statistic_dict[a].accept_cnt = self.statistic_dict[a].accept_cnt + u
            end
            self.statistic_dict[a].delete_cnt = self.statistic_dict[a].delete_cnt + l.rangeLength
            if c <= 1 then
                self.statistic_dict[a].insert_with_completion_cnt = self.statistic_dict[a].insert_with_completion_cnt + u
                if u <= MAX_ACCEPT_LENGTH or c == 1 then
                    self.statistic_dict[a].insert_with_completion_without_paste_cnt = self.statistic_dict[a].insert_with_completion_without_paste_cnt + u
                end
            end
        end
    end
end

function CompletionStatistics:check_accept(e, r, n, i)
    if r.current_completion then
        local s = e:offsetAt(r.current_completion.position)
        local completion = r.current_completion.response.completions[1]
        if completion then
            local generated_text = completion.generated_text
            local start_pos = n - s + 1
            local end_pos = start_pos + #i - 1
            local a = generated_text:sub(start_pos, end_pos)
            return i == a and 1 or 0
        end
    end
    return 2
end

function CompletionStatistics:update_user_id(user_id)
    self.user_id = user_id
end

function CompletionStatistics:update_edit_mode_status(uri, action)
    if not self.statistic_dict[uri] then
        self.statistic_dict[uri] = Record.new()
    end

    if action == 0 then
        self.statistic_dict[uri].edit_show_cnt = self.statistic_dict[uri].edit_show_cnt + 1
    elseif action == 1 then
        self.statistic_dict[uri].edit_cancel_cnt = self.statistic_dict[uri].edit_cancel_cnt + 1
    elseif action == 2 then
        self.statistic_dict[uri].edit_accept_cnt = self.statistic_dict[uri].edit_accept_cnt + 1
    end
end

function CompletionStatistics:update_completion_time(uri, time, is_pc)
    if not self.statistic_dict[uri] then
        self.statistic_dict[uri] = Record.new()
    end
    if is_pc then
        self.statistic_dict[uri].is_pc_cnt = self.statistic_dict[uri].is_pc_cnt + 1
    else
        self.statistic_dict[uri].is_pc_cnt = self.statistic_dict[uri].is_pc_cnt - 1
    end
    self.statistic_dict[uri].completion_times = self.statistic_dict[uri].completion_times + 1
    self.statistic_dict[uri].completion_total_time = self.statistic_dict[uri].completion_total_time + time
end

function CompletionStatistics:send_one_status(status)
    Client.request(Protocol.Methods.statistic_log, {
        variables = {
            completion_statistics = status
        }
    })
end

-- "2025-03-08"
function CompletionStatistics:get_current_date()
    return vim.fn.strftime('%Y-%m-%d')
end

function CompletionStatistics:update_tracker(current)
    local completion_tracker = Tracker.mutable_completion()
    local time = self:get_current_date()
    local entry = completion_tracker[time]
    if not entry then
        completion_tracker[time] = current
    else
        entry.accept_cnt = entry.accept_cnt and entry.accept_cnt + current.accept_cnt or current.accept_cnt
        entry.insert_without_paste_cnt = entry.insert_without_paste_cnt and entry.insert_without_paste_cnt + current.insert_without_paste_cnt or current.insert_without_paste_cnt
    end
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
            gray_status = vim.json.encode((GrayTestHelper.get_all_results())),
            chosen = tostring(chosen),
            is_pc = stats.is_pc_cnt > 0 and '1' or '0',
            completion_type = completion_type,
            pc_prompt_type = last_chosen_prompt_type,
            ide = Extension.ide_name
        }
        local s = {
            user_id = user_id,
            has_lsp = tostring(i == 1),
            enabled = open,
            tag = vim.json.encode(tag),
            chosen = tostring(chosen),
            use_project_completion = tostring(use_project_completion),
            uri = uri,
            accept_cnt = tostring(stats.accept_cnt),
            insert_without_paste_cnt = tostring(stats.insert_without_paste_cnt),
            insert_cnt = tostring(stats.insert_cnt),
            delete_cnt = tostring(stats.delete_cnt),
            completion_times = tostring(stats.completion_times),
            completion_total_time = tostring(stats.completion_total_time),
            insert_with_completion_without_paste_cnt = tostring(stats.insert_with_completion_without_paste_cnt),
            insert_with_completion_cnt = tostring(stats.insert_with_completion_cnt),
            edit_show_cnt = tostring(stats.edit_show_cnt),
            edit_cancel_cnt = tostring(stats.edit_cancel_cnt),
            edit_accept_cnt = tostring(stats.edit_accept_cnt),
            edit_change_config = tostring(stats.edit_change_config)
        }
        self:update_tracker(s)
        local query = URLSearchParams.new()
        for k, v in pairs(s) do
            query:append(k, v)
        end
        local status = query:to_string()
        self:send_one_status(status)
        stats:reset()
        ::continue::
    end
end

return CompletionStatistics
