---@class fittencode.CompletionStatistics
local CompletionStatistics = {}
CompletionStatistics.__index = CompletionStatistics

function CompletionStatistics:new(params)
    local instance = {}
    setmetatable(instance, CompletionStatistics)
    return instance
end

function CompletionStatistics:update_ft_token(ft_token)
    self.ft_token = ft_token
end

function CompletionStatistics:check_accept()
end

function CompletionStatistics:send_one_status()
end

function CompletionStatistics:update_completion_time()
end

function CompletionStatistics:send_status()
end
