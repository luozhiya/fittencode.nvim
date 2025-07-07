local bit = require('bit')

local M = {}

function M.schedule_call(fx, ...)
    if fx then
        local args = { ... }
        vim.schedule(function()
            fx(unpack(args))
        end)
    end
end

function M.check_call(fx, ...)
    if fx then
        local args = { ... }
        return fx(unpack(args))
    end
end

function M.debounce(func, delay, on_return)
    local timer = nil
    if not delay or tonumber(delay) <= 0 then
        return function(...)
            local args = { ... }
            vim.schedule(function()
                local v = func(unpack(args))
                M.check_call(on_return, v)
            end)
        end
    end
    return function(...)
        local args = { ... }
        if timer then
            timer:stop()
        end
        timer = vim.uv.new_timer()
        if not timer then
            return
        end
        timer:start(delay, 0, function()
            timer:close()
            vim.schedule(function()
                local v = func(unpack(args))
                M.check_call(on_return, v)
            end)
        end)
    end
end

---@param s string
---@param prefix string
---@return boolean
function M.startswith(s, prefix)
    return string.sub(s, 1, string.len(prefix)) == prefix
end

function M.uuid()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function M.random(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123455789'
    local result = {}
    for i = 1, length do
        local index = math.random(1, #chars)
        table.insert(result, chars:sub(index, index))
    end
    return table.concat(result)
end

function M.generate_short_id(length)
    length = length or 8
    return M.random(36):sub(2, 2 + length)
end

function M.generate_short_id_as_string(length)
    return '(' .. M.generate_short_id(length) .. ')'
end

function M.is_dark_colorscheme()
    -- 获取 Normal 组的背景色
    local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
    local bg_color = normal_hl.bg or 0 -- 默认为黑色 (0)

    -- 提取 RGB 分量
    local r = bit.rshift(bit.band(bg_color, 0xff0000), 16)
    local g = bit.rshift(bit.band(bg_color, 0x00ff00), 8)
    local b = bit.band(bg_color, 0x0000ff)

    -- 计算相对亮度 (公式: ITU-R BT.709)
    local luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255

    -- 判断亮度阈值
    return luminance < 0.5 -- < 0.5 为深色
end

return M
