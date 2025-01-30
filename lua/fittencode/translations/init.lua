local Fn = require('fittencode.fn')
local Language = require('fittencode.language')
local Config = require('fittencode.config')
local Log = require('fittencode.log')

local M = {}

-- 分层翻译存储结构
local translation_layers = {
    system = {}, -- 系统核心翻译
    user = {}    -- 用户自定义翻译
}

-- 注册翻译层
function M.register_translations(layer, lang, translations)
    if not translation_layers[layer] then
        Log.warn('Invalid translation layer: ' .. layer)
        return
    end

    translation_layers[layer][lang] = translations
end

-- 获取当前语言
local function get_target_lang()
    local raw_lang = Language.display_preference()
    return raw_lang:gsub('_', '-'):lower() -- 统一格式为 en-us 形式
end

-- 生成翻译查找链
local function get_lang_chain(target_lang)
    local parts = vim.split(target_lang, '-')
    return {
        target_lang, -- 完整语言代码
        parts[1],    -- 主语言代码
        'default'    -- 最终回退
    }
end

-- 合并翻译结果
local function merge_translations(lang_chain)
    local merged = {}
    for _, layer in ipairs({ 'system', 'user' }) do
        for _, lang in ipairs(lang_chain) do
            if translation_layers[layer][lang] then
                merged = vim.tbl_extend('force', merged, translation_layers[layer][lang])
            end
        end
    end
    return merged
end

-- 核心翻译逻辑
function M.translate(key, ...)
    local target_lang = get_target_lang()
    local lang_chain = get_lang_chain(target_lang)
    local translations = merge_translations(lang_chain)

    -- 查找翻译
    local result = translations[key] or key

    -- 开发环境警告缺失翻译
    if Config.developer_mode and result == key then
        Log.debug(('Missing translation: [%s] %s'):format(target_lang, key))
    end

    -- 格式化处理
    return Fn.simple_format(result, ...)
end

-- 初始化核心系统翻译
M.register_translations('system', 'zh', require('translations.zh'))
M.register_translations('system', 'en', require('translations.en'))

return M
