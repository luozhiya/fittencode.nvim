local Config = require('fittencode.config')

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
local function startwith(s, prefix)
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

local tzlangs = {
    ['+0000'] = 'en',    -- Greenwich Mean Time
    ['+0800'] = 'zh-cn', -- China Standard Time
}

setmetatable(tzlangs, {
    __index = function()
        return tzlangs['+0000']
    end
})

local function timezone_language()
    return tzlangs[os.date('%z')]
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

local function display_preference()
    local dp = Config.language_preference.display_preference
    if not dp or #dp == 0 or dp == 'auto' then
        return timezone_language()
    end
    return dp
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

local function utf8(decimal)
    local bytemarkers = { { 0x7FF, 192 }, { 0xFFFF, 224 }, { 0x1FFFFF, 240 } }
    if decimal < 128 then return string.char(decimal) end
    local charbytes = {}
    for bytes, vals in ipairs(bytemarkers) do
        if decimal <= vals[1] then
            for b = bytes + 1, 2, -1 do
                local mod = decimal % 64
                decimal = (decimal - mod) / 64
                charbytes[b] = string.char(128 + mod)
            end
            charbytes[1] = string.char(vals[2] + decimal)
            break
        end
    end
    return table.concat(charbytes)
end

local function unicode_sequence_to_utf8(seq)
    local v = vim.split(seq, '\\u', { trimempty = true })
    local s = ''
    for i, code in ipairs(v) do
        local c = utf8(tonumber(code, 16))
        s = s .. c
    end
    return s
end

return {
    debounce = debounce,
    schedule_call = schedule_call,
    schedule_call_wrap_fn = schedule_call_wrap_fn,
    schedule_call_foreach = schedule_call_foreach,
    startwith = startwith,
    fs_all_entries = fs_all_entries,
    timezone_language = timezone_language,
    display_preference = display_preference,
    format = format,
    slice = slice,
    remove_special_token = remove_special_token,
    is_windows = is_windows,
    is_linux = is_linux,
    unicode_sequence_to_utf8 = unicode_sequence_to_utf8,
}
