-- 判断操作系统类型
local function get_os()
    return package.config:sub(1, 1) == '\\' and 'windows' or 'unix'
end

-- Windows: 通过 GetUserDefaultLocaleName 获取 BCP 47 格式的地区代码（宽字符版本）
local function get_locale_from_locale_name()
    local ffi = require('ffi')
    ffi.cdef [[
        typedef unsigned short wchar_t;
        int GetUserDefaultLocaleName(wchar_t* lpLocaleName, int cchLocaleName);
    ]]

    -- 初始化宽字符缓冲区
    local buffer_size = 85                            -- LOCALE_NAME_MAX_LENGTH 是 85
    local buffer = ffi.new('wchar_t[?]', buffer_size) -- 动态分配宽字符缓冲区
    ffi.fill(buffer, buffer_size * 2, 0)              -- 每个 wchar_t 占 2 字节

    -- 调用宽字符 API
    local result = ffi.C.GetUserDefaultLocaleName(buffer, buffer_size)

    -- 检查返回值
    if result > 0 then
        -- 将宽字符转换为 UTF-8 字符串
        local raw_str = ffi.string(buffer, result * 2) -- 每个字符 2 字节
        -- 只支持 ASCII 字符，提取 wchar_t 的前半部分
        -- 小端（Little Endian）
        local utf8_str
        for i = 1, #raw_str, 2 do
            local c = string.char(raw_str:byte(i))
            if c ~= '\0' then
                utf8_str = utf8_str and utf8_str .. c or c
            end
        end
        return utf8_str
    end

    return nil
end

-- Windows: 通过 LCID 获取 BCP 47 格式的地区代码
local function get_locale_from_lcid()
    local ffi = require('ffi')
    ffi.cdef [[
        typedef unsigned long LCID;
        LCID GetUserDefaultLCID();
        int GetLocaleInfoA(LCID Locale, int LCType, char* lpLCData, int cchData);
    ]]

    -- 获取 LCID
    local lcid = ffi.C.GetUserDefaultLCID()
    if lcid == 0 then return nil end

    -- 定义常量
    local LOCALE_SISO639LANGNAME = 0x0059  -- ISO 639 语言代码（如 "en"）
    local LOCALE_SISO3166CTRYNAME = 0x005A -- ISO 3166 国家代码（如 "US"）

    -- 获取语言代码
    local lang_buffer = ffi.new('char[16]')
    local lang_result = ffi.C.GetLocaleInfoA(lcid, LOCALE_SISO639LANGNAME, lang_buffer, 16)
    if lang_result == 0 then return nil end
    local lang = ffi.string(lang_buffer):lower()

    -- 获取国家代码
    local country_buffer = ffi.new('char[16]')
    local country_result = ffi.C.GetLocaleInfoA(lcid, LOCALE_SISO3166CTRYNAME, country_buffer, 16)
    if country_result == 0 then return lang end -- 若国家代码不可用，返回仅语言代码
    local country = ffi.string(country_buffer):upper()

    return lang .. '-' .. country
end

-- 获取系统语言设置（跨平台）
local function get_system_locale()
    local os_type = get_os()

    if os_type == 'windows' then
        -- 优先尝试宽字符 API GetUserDefaultLocaleName
        local locale = get_locale_from_locale_name()
        if locale then
            return locale
        end

        -- 如果失败，回退到 LCID 方法
        return get_locale_from_lcid()
    else
        -- Linux/macOS: 使用 locale 命令
        local handle = io.popen('locale | grep LANG=')
        if handle then
            local result = handle:read('*a')
            handle:close()
            local lang_code = result:match('LANG=([^%.]+)')
            return lang_code and lang_code:gsub('_', '-') -- 直接转换为 BCP 47
        end
    end

    return nil
end

-- 获取时区偏移量（备选方案）
local function get_timezone_offset()
    return os.date('%z') -- 格式为 +HHMM 或 -HHMM
end

-- 时区偏移量到地区的映射表
local timezone_map = {
    ['+0800'] = 'zh-CN', -- 中国
    ['-0500'] = 'en-US', -- 美国东部
    ['+0000'] = 'en-GB', -- 英国
}

setmetatable(timezone_map, {
    __index = function()
        return 'en'
    end
})

-- For example, `en-US` is the BCP 47 format of the US English locale.
---@return string
local function get_locale()
    -- 1. 尝试获取系统语言设置
    local locale = get_system_locale()

    -- 2. 直接输出结果
    if locale then
        return locale
    end

    -- 3. 若失败，尝试通过时区推断
    return timezone_map[get_timezone_offset()]
end

return {
    get_locale = get_locale,
}
