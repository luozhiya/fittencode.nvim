local LSP = require('vim.lsp')

local GlobalHeartBeater = {}
GlobalHeartBeater.__index = GlobalHeartBeater

function GlobalHeartBeater:new()
    local instance = setmetatable({}, GlobalHeartBeater)
    instance.heart_beat_gap = 30 * 1000
    instance.ban_time = 60 * 60 * 1000
    instance.timeout_threshold = 1000
    instance.check_times = 10
    instance.timeout_limit = 5
    instance.status = 0
    instance.last_ban_time = 0
    instance.last_call_time = 0
    instance.gaps = {}
    instance.last_call_time = vim.loop.hrtime() / 1e6

    vim.loop.new_timer():start(instance.heart_beat_gap, instance.heart_beat_gap, vim.schedule_wrap(function()
        local current_time = vim.loop.hrtime() / 1e6
        local r = current_time - instance.last_call_time - instance.heart_beat_gap
        instance.last_call_time = current_time

        if instance.status == 2 and current_time - instance.last_ban_time > instance.ban_time then
            instance.gaps = {}
            instance.status = 1
        end

        if instance.status == 1 then
            local start_time = vim.loop.hrtime() / 1e6
            local results_by_client, err = LSP.buf_request_sync(instance.buf, LSP.protocol.Methods.textDocument_documentSymbol, {}, instance.timeout_threshold)
            if not err then
                local duration = (vim.loop.hrtime() / 1e6 - start_time) + r
                table.insert(instance.gaps, duration)
                if #instance.gaps > instance.check_times then
                    table.remove(instance.gaps, 1)
                end
                local timeout_count = 0
                for _, gap in ipairs(instance.gaps) do
                    if gap > instance.timeout_threshold then
                        timeout_count = timeout_count + 1
                    end
                end
                if timeout_count >= instance.timeout_limit then
                    instance.status = 2
                    instance.gaps = {}
                    instance.last_ban_time = vim.loop.hrtime() / 1e6
                end
            else
                instance.status = 0
            end
        end
    end))

    return instance
end

function GlobalHeartBeater:update_buf(e)
    if self.status == 0 then
        self.buf = e
        self.status = 1
    end
end

return GlobalHeartBeater
