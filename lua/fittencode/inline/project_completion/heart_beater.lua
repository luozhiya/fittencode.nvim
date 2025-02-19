local Perf = require('fittencode.functional.performance')
local Editor = require('fittencode.document.editor')

local HeartBeater = {}
HeartBeater.__index = HeartBeater

function HeartBeater.new()
    local self = setmetatable({}, HeartBeater)
    return self
end

function HeartBeater:__reset()
    self.heart_beat_gap = 30 * 1000
    self.ban_time = 60 * 60 * 1000
    self.timeout_threshold = 1000
    self.check_times = 10
    self.timeout_limit = 5
    self.status = 0
    self.last_ban_time = 0
    self.gaps = {}
    self.last_call_time = Perf.tick()
    self.timer = nil
    self.buffer = nil
end

function HeartBeater:start(force)
    if self.timer then
        if not force then
            return
        end
        self:stop()
        self:__reset()
    end
    self.timer = vim.uv.new_timer()
    local on_timeout = vim.schedule_wrap(function()
        local now = Perf.tick()
        local gap_time = now - self.last_call_time - self.heart_beat_gap
        self.last_call_time = now

        if self.status == 2 and now - self.last_ban_time > self.ban_time then
            self.gaps = {}
            self.status = 1
        elseif self.status == 1 then
            -- vim.uri_from_bufnr 会检测 buffer name，所以这里只需检测有效性
            if not Editor.is_valid(self.buffer) then
                self.status = 0
                self.gaps = {}
                return
            end
            local start_time = Perf.tick()
            vim.lsp.buf_request(self.buffer, 'textDocument/documentSymbol', {
                textDocument = {
                    uri = vim.uri_from_bufnr(0),
                },
            }, function(err, result)
                local total_elapsed = (Perf.tick() - start_time) + gap_time
                table.insert(self.gaps, total_elapsed)
                if #self.gaps > self.check_times then
                    table.remove(self.gaps, 1)
                end
                local total = 0
                for _, gap in ipairs(self.gaps) do
                    if gap > self.timeout_threshold then
                        total = total + 1
                    end
                end
                if total >= self.timeout_limit then
                    self.status = 2
                    self.gaps = {}
                    self.last_ban_time = Perf.tick()
                end
            end, function()
                -- Unsupported method
                self.status = 0
            end)
        else
            self.status = 0
        end
    end)
    self.timer:start(self.heart_beat_gap, self.heart_beat_gap, on_timeout)
end

function HeartBeater:stop()
    if self.timer then
        self.timer:stop()
        self.timer:close()
        self.timer = nil
    end
end

function HeartBeater:update_buffer(e)
    if self.status == 0 then
        self.buffer = e
        self.status = 1
    end
end

function HeartBeater:is_banned()
    return self.status == 2
end

function HeartBeater:is_working()
    return self.status == 1
end

function HeartBeater:is_idle()
    return self.status == 0
end

function HeartBeater:get_status()
    return self.status
end

return HeartBeater
