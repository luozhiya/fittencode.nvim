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

function M.schedule_call_wrap_fn(fx, ...)
    return function(...)
        M.schedule_call(fx, ...)
    end
end

function M.schedule_call_foreach(v, ...)
    if not v then
        return
    end
    if vim.islist(v) then
        for _, fx in ipairs(v) do
            M.schedule_call(fx, ...)
        end
    else
        for _, fx in pairs(v) do
            M.schedule_call(fx, ...)
        end
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
            local v = func(...)
            M.schedule_call(on_return, v)
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
            local v = func(unpack(args))
            M.schedule_call(on_return, v)
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

function M.validate(uuid)
    local pattern = '%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x'
    return uuid:match(pattern) ~= nil
end

local byte_to_hex = {}
for i = 0, 255 do
    byte_to_hex[#byte_to_hex + 1] = string.sub(string.format('%x', i + 256), 2)
end

function M.stringify(arr)
    local uuid_parts = {
        byte_to_hex[arr[1]] .. byte_to_hex[arr[2]] .. byte_to_hex[arr[3]] .. byte_to_hex[arr[4]],
        byte_to_hex[arr[5]] .. byte_to_hex[arr[6]],
        byte_to_hex[arr[7]] .. byte_to_hex[arr[8]],
        byte_to_hex[arr[9]] .. byte_to_hex[arr[10]],
        byte_to_hex[arr[11]] .. byte_to_hex[arr[12]] .. byte_to_hex[arr[13]] .. byte_to_hex[arr[14]] .. byte_to_hex[arr[15]] .. byte_to_hex[arr[16]]
    }
    local uuid = table.concat(uuid_parts, '-')
    if not M.validate(uuid) then
        return
    end
    return uuid
end

function M.rng(len)
    math.randomseed(os.time())
    local arr = {}
    for _ = 1, len do
        arr[#arr + 1] = math.random(0, 256)
    end
    return arr
end

function M.uuid_v4()
    local rnds = M.rng(16)
    rnds[6] = bit.bor(bit.band(rnds[6], 15), 64)
    rnds[8] = bit.bor(bit.band(rnds[8], 63), 128)
    return M.stringify(rnds)
end

function M.uuid_v1()
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

function M.generate_short_id()
    return M.random(36):sub(2, 10)
end

return M
