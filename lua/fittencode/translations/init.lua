local LangPreference = require('fittencode.lang.preference')
local LangFallback = require('fittencode.lang.fallback')
local Log = require('fittencode.log')
local Fmt = require('fittencode.fmt')
local Config = require('fittencode.config')
local Fn = require('fittencode.fn')

local M = {}

local cache = {
    loaded = {},      -- 已加载的翻译文件
    translations = {} -- 合并后的翻译表
}

-- 动态加载翻译文件
local function load_translations(lang_code)
    if cache.loaded[lang_code] then return true end

    local ok, trans = pcall(require, 'translations.' .. lang_code)
    if ok then
        cache.translations[lang_code] = trans
        cache.loaded[lang_code] = true
        return true
    end

    Log.warn('Translation for {} not found', lang_code)
    return false
end

-- 获取合并翻译表
local function get_merged_translations(lang)
    local merged = {}
    local fallbacks = LangFallback.generate_chain(lang)
    for _, lang_code in ipairs(fallbacks) do
        load_translations(lang_code)
        if cache.translations[lang_code] then
            merged = vim.tbl_deep_extend('force', merged, cache.translations[lang_code])
        end
    end
    return merged
end

-- 核心翻译方法
function M.translate(key, ...)
    local lang = LangPreference.display_preference()
    local translations = get_merged_translations(lang)
    local value = translations[key] or key

    -- 开发模式警告缺失翻译
    if Config.developer_mode and lang ~= 'en' and value == key then
        Log.debug('Missing translation: {}', key)
    end

    return Fmt.format(value, ...)
end

-- 手动添加翻译
function M.add_translations(lang_code, new_trans)
    lang_code = lang_code:gsub('_', '-'):lower()
    load_translations(lang_code)
    cache.translations[lang_code] = vim.tbl_extend('force', cache.translations[lang_code] or {}, new_trans)
end

return M
