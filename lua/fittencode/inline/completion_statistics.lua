-- 定义 kS 类
local kS = {}
function kS:new()
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
    setmetatable(object, { __index = self })
    return object
end

-- 定义 sM 类
local CompletionStatistics = {}
function CompletionStatistics:new(e, r, n, i)
    local object = {
        completion_status_dict = e,
        statistic_dict = {},
        file_code_tree_dict = r,
        user_id = n,
        logger = i,
        handleTextDocumentChange = function(o)
            local a = o.document
            local A = a.uri.toString()
            if object.completion_status_dict[A] then
                local c = object.completion_status_dict[A]
                if os.time() - c.sending_time > eM then
                    return
                end
                for _, l in ipairs(o.contentChanges) do
                    local h = check_accept(a, c, l.rangeOffset, l.text)
                    local d = #l.text
                    object.statistic_dict[A].insert_cnt = object.statistic_dict[A].insert_cnt + d
                    if d <= Cie or h == 1 then
                        object.statistic_dict[A].insert_without_paste_cnt = object.statistic_dict[A].insert_without_paste_cnt + d
                    end
                    object.statistic_dict[A].delete_cnt = object.statistic_dict[A].delete_cnt + l.rangeLength
                    if h <= 1 then
                        object.statistic_dict[A].insert_with_completion_cnt = object.statistic_dict[A].insert_with_completion_cnt + d
                        if d <= Cie or h == 1 then
                            object.statistic_dict[A].insert_with_completion_without_paste_cnt = object.statistic_dict[A].insert_with_completion_without_paste_cnt + d
                        end
                    end
                    if h == 1 then
                        object.statistic_dict[A].accept_cnt = object.statistic_dict[A].accept_cnt + d
                    end
                end
            end
        end
    }
    Me.workspace.onDidChangeTextDocument = object.handleTextDocumentChange
    return object
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

function CompletionStatistics:send_one_status(e)
    local r = Me.workspace.getConfiguration('http').get('proxy')
    local n = r and require('vscode-http').ProxyAgent(r) or nil
    local i = require('die').getServerURL()
    local s = require('fetch')(i .. '/codeuser/statistic_log?' .. e, {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        dispatcher = n
    })
    return s
end

function CompletionStatistics:send_status()
    local e = Me.workspace.getConfiguration('fittencode.useProjectCompletion').get('open')
    local r = oM(self.user_id)
    for uri, stats in pairs(self.statistic_dict) do
        if self.completion_status_dict[uri] then
            local a = self.completion_status_dict[uri]
            if os.time() - a.sending_time > DHe then
                goto continue
            end
        end
        if stats.completion_times == 0 then
            goto continue
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
        self.statistic_dict[e] = kS:new()
    end
    self.statistic_dict[e].completion_times = self.statistic_dict[e].completion_times + 1
    self.statistic_dict[e].completion_total_time = self.statistic_dict[e].completion_total_time + r
end

function CompletionStatistics:getCurrentDate()
    local date = os.date('!*t')
    return string.format('%04d-%02d-%02d', date.year, date.month, date.day)
end
