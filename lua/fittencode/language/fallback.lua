local M = {}

-- 语言标签解析器
local function parse_lang_tag(lang)
    local parts = {}
    for part in lang:gmatch('[^-]+') do
        table.insert(parts, part:lower())
    end
    return {
        main = parts[1] or '',
        script = parts[2] and #parts[2] == 4 and parts[2] or nil,
        region = parts[2] and #parts[2] == 2 and parts[2]
            or parts[3] and #parts[3] == 2 and parts[3]
            or nil
    }
end

-- 生成变体列表（按优先级排序）
local function generate_variants(tag)
    local variants = {}

    -- 完整格式
    table.insert(variants, table.concat({
        tag.main,
        tag.script,
        tag.region
    }, '-'))

    -- 含脚本无地区
    if tag.script then
        table.insert(variants, tag.main .. '-' .. tag.script)
    end

    -- 含地区无脚本
    if tag.region then
        table.insert(variants, tag.main .. '-' .. tag.region)
    end

    -- 仅主语言
    table.insert(variants, tag.main)

    -- 标准别名处理
    if tag.main == 'zh' then
        if tag.script == 'hans' then
            table.insert(variants, 'zh-cn')
            table.insert(variants, 'zh-sg')
        elseif tag.script == 'hant' then
            table.insert(variants, 'zh-tw')
            table.insert(variants, 'zh-hk')
            table.insert(variants, 'zh-mo')
        end
    end

    return variants
end

-- 智能生成回退链
function M.generate_chain(lang, final_fallback)
    lang = lang:gsub('_', '-'):lower()
    local tag = parse_lang_tag(lang)
    local variants = generate_variants(tag)

    -- 构建完整链
    local chain = {}
    local seen = {}

    -- 添加当前语言变体
    for _, v in ipairs(variants) do
        if not seen[v] then
            table.insert(chain, v)
            seen[v] = true
        end
    end

    -- 添加通用回退
    if tag.main ~= 'en' then
        table.insert(chain, 'en')
    end

    -- 添加最终配置回退
    for _, fb in ipairs(final_fallback or {}) do
        if fb ~= 'en' and not seen[fb] then
            table.insert(chain, fb)
        end
    end

    return chain
end

-- 示例测试
-- print(vim.inspect(M.generate_chain('zh-Hans-CN')))
-- 输出: { "zh-hans-cn", "zh-hans", "zh-cn", "zh", "zh-sg", "en" }

return M
