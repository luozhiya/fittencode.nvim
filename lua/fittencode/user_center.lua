---@class fittencode.UserCenter
---@field number_of_7days_acceptances integer
---@field cumulative_number_of_acceptances integer
---@field number_of_days_of_acceptance integer
---@field number_of_characters_accepted_in_7days integer
---@field cumulative_number_of_accepted_characters integer
---@field cumulative_number_of_times_the_right_click_function_has_been_used integer
---@field acceptance_rate number
---@field calendar table<string, table<integer, integer>>
local data = nil

-- local data = {
--     -- 七日接受次数
--     number_of_7days_acceptances = 0,
--     -- 累计接受次数
--     cumulative_number_of_acceptances = 0,
--     -- 接受天数
--     number_of_days_of_acceptance = 0,
--     -- 七日接受字符数
--     number_of_characters_accepted_in_7days = 0,
--     -- 累计接受字符数
--     cumulative_number_of_accepted_characters = 0,
--     -- 右键功能累计使用次数
--     cumulative_number_of_times_the_right_click_function_has_been_used = 0,
--     -- 接收率
--     acceptance_rate = 0,
--     -- 日历
--     calendar = {
--         -- ['2024-10-01'] = {
--         --     0,
--         --     0,
--         -- },
--     }
-- }

local data_store = vim.fn.stdpath('data') .. '/fittencode' .. '/user_center.json'

local function load()
    if vim.fn.filereadable(data_store) == 1 then
        data = vim.fn.json_decode(vim.fn.readfile(data_store))
    else
        data = {
            number_of_7days_acceptances = 0,
            cumulative_number_of_acceptances = 0,
            number_of_days_of_acceptance = 0,
            number_of_characters_accepted_in_7days = 0,
            cumulative_number_of_accepted_characters = 0,
            cumulative_number_of_times_the_right_click_function_has_been_used = 0,
            acceptance_rate = 0,
            calendar = {}
        }
    end
end

local function save()
    if data then
        vim.fn.writefile(vim.fn.json_encode(data), data_store)
    end
end

local function tick(action, opts)
    if not data then
        load()
    end
    local date = os.date('%Y-%m-%d')
    if not data.calendar[date] then
        data.calendar[date] = { 0, 0 }
    end
    if action == 'acceptance' then
        data.calendar[date][1] = data.calendar[date][1] + 1
        if type(opts.characters) == 'number' then
            data.calendar[date][2] = data.calendar[date][2] + opts.characters
        end
    elseif action == 'right_click' then
        data.cumulative_number_of_times_the_right_click_function_has_been_used =
            data.cumulative_number_of_times_the_right_click_function_has_been_used + 1
    end
end

vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
    group = vim.api.nvim_create_augroup('fittencode.user_center', { clear = true }),
    pattern = '*',
    callback = function()
        save()
    end,
})

---@class fittencode.chat.CompletionStatistics
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

return {
    tick = tick,
}
