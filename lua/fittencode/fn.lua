local BIT = require('bit')

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

-- 将时区偏移量映射到语言代码
local timezone_language_mapping = {
    ['+0000'] = 'en',    -- Greenwich Mean Time
    ['+0800'] = 'zh-cn', -- China Standard Time
}

setmetatable(timezone_language_mapping, {
    __index = function()
        return timezone_language_mapping['+0000']
    end
})

-- 获取当前时区对应的语言
-- * 返回的语言代码符合 ISO-639 / ISO-3166 标准
-- * 如果无法获取到时区对应的语言，则返回默认语言 'en'
local function get_timezone_based_language()
    return timezone_language_mapping[os.date('%z')]
end

local function pack(...)
    return { n = select('#', ...), ... }
end

local function format(msg, ...)
    ---@type string
    msg = msg or ''
    local args = pack(...)
    for i = 1, args.n do
        local arg = args[i]
        if arg == nil then
            msg = msg:gsub('{}', '%%s', 1)
            args[i] = 'nil'
        elseif type(arg) == 'integer' or type(arg) == 'number' then
            if arg == math.floor(arg) then
                msg = msg:gsub('{}', '%%d', 1)
            else
                msg = msg:gsub('{}', '%%.3f', 1)
            end
        elseif type(arg) == 'string' then
            msg = msg:gsub('{}', '%%s', 1)
        else
            msg = msg:gsub('{}', '%%s', 1)
            args[i] = vim.inspect(arg)
        end
    end
    local ok, vfmt = pcall(string.format, msg, unpack(args))
    if ok then
        return vfmt
    end
    return msg
end

local function slice(t, start)
    local result = {}
    for i = start, #t do
        table.insert(result, t[i])
    end
    return result
end

local function remove_special_token(t)
    return string.gsub(t, '<|(%w{%d,10})|>', '<| %1 |>')
end

local function sysname() return vim.uv.os_uname().sysname:lower() end
local function is_windows() return sysname():find('windows') ~= nil end
local function is_linux() return sysname():find('linux') ~= nil end

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
    rnds[6] = BIT.bor(BIT.band(rnds[6], 15), 64)
    rnds[8] = BIT.bor(BIT.band(rnds[8], 63), 128)
    return stringify(rnds)
end

-- 复制 on_ 开头的事件到新的 table
-- 禁止：不允许在 c 中添加 on_ 开头的事件
-- 这个函数仅仅适用于不修改回调，但需要修改其他数据情况下使用
local function tbl_keep_events(a, c)
    for k, v in pairs(c) do
        if startswith(k, 'on_') then
            return
        end
    end
    local b = {}
    for k, v in pairs(a) do
        if startswith(k, 'on_') then
            b[k] = v
        end
    end
    return vim.tbl_deep_extend('force', b, c)
end

local function extension_uri()
    local current_dir = debug.getinfo(1, 'S').source:sub(2):gsub('fn.lua', '')
    return current_dir:gsub('/lua$', '') .. '../../'
end

local function normalize_path(path)
    return is_windows() and path:gsub('/', '\\') or path:gsub('\\', '/')
end

return {
    debounce = debounce,
    schedule_call = schedule_call,
    schedule_call_wrap_fn = schedule_call_wrap_fn,
    schedule_call_foreach = schedule_call_foreach,
    check_call = check_call,
    startswith = startswith,
    fs_all_entries = fs_all_entries,
    get_timezone_based_language = get_timezone_based_language,
    format = format,
    slice = slice,
    remove_special_token = remove_special_token,
    is_windows = is_windows,
    is_linux = is_linux,
    uuid_v4 = uuid_v4,
    tbl_keep_events = tbl_keep_events,
    extension_uri = extension_uri,
    normalize_path = normalize_path,
}
