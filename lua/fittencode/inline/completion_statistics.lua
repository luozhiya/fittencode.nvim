local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')

local SENDING_TIME_INTERVAL = 1e3 * 60 * 10
local SEND_TIME_INTERVAL = 1e3 * 60 * 5
local MAX_TEXT_LENGTH = 5

local Record = {}

function Record:new()
    local object = {
        delete_cnt = 0,
        insert_without_paste_cnt = 0,
        insert_cnt = 0,
        accept_cnt = 0,
        insert_with_completion_without_paste_cnt = 0,
        insert_with_completion_cnt = 0,
        completion_times = 0,
        completion_total_time = 0
    }
    setmetatable(object, { __index = Record })
    return object
end

local CompletionStatistics = {}

function CompletionStatistics:new(e, r, n, i)
    local object = {
        completion_status_dict = e,
        statistic_dict = {},
        file_code_tree_dict = r,
        user_id = n,
        logger = i,
    }
    setmetatable(object, { __index = CompletionStatistics })
    object:__initialize()
    return object
end

function CompletionStatistics:__initialize()
    self.handle_text_document_change = function(buf)
        local uri = buf.uri
        if self.completion_status_dict[uri] then
            local completion_status = self.completion_status_dict[uri]
            if vim.uv.now() - completion_status.sending_time > SEND_TIME_INTERVAL then
                return
            end
            for _, l in ipairs(buf.contentChanges) do
                local h = self:check_accept(buf, completion_status, l.rangeOffset, l.text)
                local d = #l.text
                self.statistic_dict[uri].insert_cnt = self.statistic_dict[uri].insert_cnt + d
                if d <= MAX_TEXT_LENGTH or h == 1 then
                    self.statistic_dict[uri].insert_without_paste_cnt = self.statistic_dict[uri].insert_without_paste_cnt + d
                end
                self.statistic_dict[uri].delete_cnt = self.statistic_dict[uri].delete_cnt + l.rangeLength
                if h <= 1 then
                    self.statistic_dict[uri].insert_with_completion_cnt = self.statistic_dict[uri].insert_with_completion_cnt + d
                    if d <= MAX_TEXT_LENGTH or h == 1 then
                        self.statistic_dict[uri].insert_with_completion_without_paste_cnt = self.statistic_dict[uri].insert_with_completion_without_paste_cnt + d
                    end
                end
                if h == 1 then
                    self.statistic_dict[uri].accept_cnt = self.statistic_dict[uri].accept_cnt + d
                end
            end
        end
    end
    -- on_did_change_text_document = self.handle_text_document_change
end

function CompletionStatistics:update_user_id(e)
    self.user_id = e
end

function CompletionStatistics:check_accept(e, r, n, i)
    if r.current_completion then
        local s = e.offsetAt(r.current_completion.position)
        local a = r.current_completion.response.completions[0].generated_text
        local substring = a:sub(n - s + 1, n - s + #i)
        return i == substring and 1 or 0
    else
        return 2
    end
end

function CompletionStatistics:send_one_status(tracker_msg)
    Client.request(Protocol.statistic_log, {
        variables = {
            query = tracker_msg
        }
    })
end

function CompletionStatistics:send_status()
    local e = Me.workspace.getConfiguration('fittencode.useProjectCompletion').get('open')
    local r = oM(self.user_id)
    -- pc_check_auth
    for uri, stats in pairs(self.statistic_dict) do
        if self.completion_status_dict[uri] then
            local a = self.completion_status_dict[uri]
            if vim.uv.now() - a.sending_time > SENDING_TIME_INTERVAL then
                ::continue::
            end
        end
        if stats.completion_times == 0 then
            ::continue::
        end
        local s = {
            user_id = self.user_id,
            enabled = tostring(e),
            chosen = tostring(r),
            uri = uri,
            accept_cnt = tostring(stats.accept_cnt),
            insert_without_paste_cnt = tostring(stats.insert_without_paste_cnt),
            insert_cnt = tostring(stats.insert_cnt),
            delete_cnt = tostring(stats.delete_cnt),
            completion_times = tostring(stats.completion_times),
            completion_total_time = tostring(stats.completion_total_time),
            insert_with_completion_without_paste_cnt = tostring(stats.insert_with_completion_without_paste_cnt),
            insert_with_completion_cnt = tostring(stats.insert_with_completion_cnt)
        }
        local o = ''
        for k, v in pairs(s) do
            o = o .. k .. '=' .. v .. '&'
        end
        o = o:sub(1, -2)
        self:send_one_status(o)
        stats.accept_cnt = 0
        stats.insert_without_paste_cnt = 0
        stats.insert_cnt = 0
        stats.delete_cnt = 0
        stats.completion_times = 0
        stats.completion_total_time = 0
        stats.insert_with_completion_without_paste_cnt = 0
        stats.insert_with_completion_cnt = 0
    end
end

function CompletionStatistics:update_completion_time(e, r)
    if not self.statistic_dict[e] then
        self.statistic_dict[e] = Record:new()
    end
    self.statistic_dict[e].completion_times = self.statistic_dict[e].completion_times + 1
    self.statistic_dict[e].completion_total_time = self.statistic_dict[e].completion_total_time + r
end

return CompletionStatistics
