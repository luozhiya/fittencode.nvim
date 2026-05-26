local M = {}

function M.build_suffix(selected_model, search_enabled)
    local suffix = search_enabled and '@FCPS ' or ''
    if selected_model == 'deepseek_v3' then
        return suffix .. '@FCV9 '
    elseif selected_model == 'deepseek_r1' then
        return suffix .. '@FCVa '
    end
    return suffix
end

function M.strip_suffix(content)
    if not content then
        return content
    end
    local result = content
    while #result >= 6 and result:sub(-6):match('^@FC') do
        result = result:sub(1, -7)
    end
    return result
end

return M
