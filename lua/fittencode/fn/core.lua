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

---@param path string
---@param prename table
---@return table
function M.fs_all_entries(path, prename)
    local fs = vim.uv.fs_scandir(path)
    local res = {}
    if not fs then return res end
    local name, fs_type = vim.uv.fs_scandir_next(fs)
    while name do
        res[#res + 1] = { fs_type = fs_type, prename = prename, name = name, path = path .. '/' .. name }
        if fs_type == 'directory' then
            local prename_next = vim.deepcopy(prename)
            prename_next[#prename_next + 1] = name
            local new = M.fs_all_entries(path .. '/' .. name, prename_next)
            vim.list_extend(res, new)
        end
        name, fs_type = vim.uv.fs_scandir_next(fs)
    end
    return res
end

function M.slice(t, start)
    local result = {}
    for i = start, #t do
        table.insert(result, t[i])
    end
    return result
end

function M.uuid()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function M.clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

-- 获取原始唯一标识符的方法
function M.get_unique_identifier(tbl)
    if type(tbl) ~= 'table' then
        return
    end
    local mt = getmetatable(tbl)
    local __tostring = mt and mt.__tostring
    if __tostring then
        mt.__tostring = nil -- 临时移除 __tostring 方法
    end
    local unique_id = tostring(tbl)
    if __tostring then
        mt.__tostring = __tostring -- 恢复 __tostring 方法
    end
    unique_id = unique_id:match('table: (0x.*)')
    return unique_id
end

function M.reverse(tbl)
    local reversed = {}
    local size = #tbl
    for i = 1, size do
        reversed[i] = tbl[size - i + 1]
    end
    return reversed
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

-- "2025-03-08"
function M.get_current_date()
    return vim.fn.strftime('%Y-%m-%d')
end

function M.set_timeout(timeout, callback)
    local timer = vim.uv.new_timer()
    assert(timer)
    timer:start(timeout, 0, function()
        timer:stop()
        timer:close()
        callback()
    end)
    return timer
end

function M.set_interval(interval, callback)
    local timer = vim.uv.new_timer()
    assert(timer)
    timer:start(interval, interval, function()
        callback()
    end)
    return timer
end

function M.clear_interval(timer)
    if timer then
        timer:stop()
        timer:close()
    end
end

function M.augroup(tag, name)
    return vim.api.nvim_create_augroup('FittenCode.' .. tag .. '.' .. name, { clear = true })
end

function M.filereadable(path)
    local ok, res = pcall(vim.fn.filereadable, path)
    if not ok then
        return false
    end
    return res == 1
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
