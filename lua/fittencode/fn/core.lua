local bit = require('bit')

local function schedule_call(fx, ...)
    if fx then
        local args = { ... }
        vim.schedule(function()
            fx(unpack(args))
        end)
    end
end

local function schedule_call_wrap_fn(fx, ...)
    return function(...)
        schedule_call(fx, ...)
    end
end

local function schedule_call_foreach(v, ...)
    if not v then
        return
    end
    if vim.islist(v) then
        for _, fx in ipairs(v) do
            schedule_call(fx, ...)
        end
    else
        for _, fx in pairs(v) do
            schedule_call(fx, ...)
        end
    end
end

local function check_call(fx, ...)
    if fx then
        local args = { ... }
        return fx(unpack(args))
    end
end

local function debounce(func, delay, on_return)
    local timer = nil
    if not delay or tonumber(delay) <= 0 then
        return function(...)
            local v = func(...)
            schedule_call(on_return, v)
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
            schedule_call(on_return, v)
        end)
    end
end

---@param s string
---@param prefix string
---@return boolean
local function startswith(s, prefix)
    return string.sub(s, 1, string.len(prefix)) == prefix
end

---@param path string
---@param prename table
---@return table
local function fs_all_entries(path, prename)
    local fs = vim.uv.fs_scandir(path)
    local res = {}
    if not fs then return res end
    local name, fs_type = vim.uv.fs_scandir_next(fs)
    while name do
        res[#res + 1] = { fs_type = fs_type, prename = prename, name = name, path = path .. '/' .. name }
        if fs_type == 'directory' then
            local prename_next = vim.deepcopy(prename)
            prename_next[#prename_next + 1] = name
            local new = fs_all_entries(path .. '/' .. name, prename_next)
            vim.list_extend(res, new)
        end
        name, fs_type = vim.uv.fs_scandir_next(fs)
    end
    return res
end

local function slice(t, start)
    local result = {}
    for i = start, #t do
        table.insert(result, t[i])
    end
    return result
end

local function validate(uuid)
    local pattern = '%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x'
    return uuid:match(pattern) ~= nil
end

local byte_to_hex = {}
for i = 0, 255 do
    byte_to_hex[#byte_to_hex + 1] = string.sub(string.format('%x', i + 256), 2)
end

local function stringify(arr)
    local uuid_parts = {
        byte_to_hex[arr[1]] .. byte_to_hex[arr[2]] .. byte_to_hex[arr[3]] .. byte_to_hex[arr[4]],
        byte_to_hex[arr[5]] .. byte_to_hex[arr[6]],
        byte_to_hex[arr[7]] .. byte_to_hex[arr[8]],
        byte_to_hex[arr[9]] .. byte_to_hex[arr[10]],
        byte_to_hex[arr[11]] .. byte_to_hex[arr[12]] .. byte_to_hex[arr[13]] .. byte_to_hex[arr[14]] .. byte_to_hex[arr[15]] .. byte_to_hex[arr[16]]
    }
    local uuid = table.concat(uuid_parts, '-')
    if not validate(uuid) then
        return
    end
    return uuid
end

local function rng(len)
    math.randomseed(os.time())
    local arr = {}
    for _ = 1, len do
        arr[#arr + 1] = math.random(0, 256)
    end
    return arr
end

local function uuid_v4()
    local rnds = rng(16)
    rnds[6] = bit.bor(bit.band(rnds[6], 15), 64)
    rnds[8] = bit.bor(bit.band(rnds[8], 63), 128)
    return stringify(rnds)
end

local function uuid_v1()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

-- 获取原始唯一标识符的方法
local function get_unique_identifier(tbl)
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

local function reverse(tbl)
    local reversed = {}
    local size = #tbl
    for i = 1, size do
        reversed[i] = tbl[size - i + 1]
    end
    return reversed
end

local function random(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}
    for i = 1, length do
        local index = math.random(1, #chars)
        table.insert(result, chars:sub(index, index))
    end
    return table.concat(result)
end

-- "2025-03-08"
local function get_current_date()
    return vim.fn.strftime('%Y-%m-%d')
end

local function set_timeout(timeout, callback)
    local timer = vim.uv.new_timer()
    assert(timer)
    timer:start(timeout, 0, function()
        timer:stop()
        timer:close()
        callback()
    end)
    return timer
end

local function set_interval(interval, callback)
    local timer = vim.uv.new_timer()
    assert(timer)
    timer:start(interval, interval, function()
        callback()
    end)
    return timer
end

local function clear_interval(timer)
    if timer then
        timer:stop()
        timer:close()
    end
end

local function augroup(tag, name)
    return vim.api.nvim_create_augroup('FittenCode.' .. tag .. '.' .. name, { clear = true })
end

local function filereadable(path)
    local ok, res = pcall(vim.fn.filereadable, path)
    if not ok then
        return false
    end
    return res == 1
end

return {
    clamp = clamp,
    debounce = debounce,
    schedule_call = schedule_call,
    schedule_call_wrap_fn = schedule_call_wrap_fn,
    schedule_call_foreach = schedule_call_foreach,
    check_call = check_call,
    startswith = startswith,
    fs_all_entries = fs_all_entries,
    slice = slice,
    uuid_v4 = uuid_v4,
    uuid_v1 = uuid_v1,
    get_unique_identifier = get_unique_identifier,
    reverse = reverse,
    random = random,
    get_current_date = get_current_date,
    set_timeout = set_timeout,
    set_interval = set_interval,
    clear_interval = clear_interval,
    augroup = augroup,
    filereadable = filereadable
}
