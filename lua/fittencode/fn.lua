local Config = require('fittencode.config')

local function schedule_call(fx, ...)
    if fx then
        local args = { ... }
        vim.schedule(function()
            fx(unpack(args))
        end)
    end
end

local function debounce(func, delay)
    local timer = nil
    if not delay or tonumber(delay) <= 0 then
        return func
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
            func(unpack(args))
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

local function format(msg, ...)
    ---@type string
    msg = msg or ''
    local args = { ... }
    for i, arg in ipairs(args) do
        if type(arg) == 'integer' then
            msg = msg:gsub('{}', '%%d', 1)
        elseif type(arg) == 'number' then
            msg = msg:gsub('{}', '%%.2f', 1)
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

return {
    debounce = debounce,
    schedule_call = schedule_call,
    startwith = startwith,
    fs_all_entries = fs_all_entries,
    timezone_language = timezone_language,
    display_preference = display_preference,
    format = format,
    slice = slice,
    remove_special_token = remove_special_token,
}
