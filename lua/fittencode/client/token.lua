local M = {}

-- 通过添加空格的方式来规避特殊token
function M.remove_special_token(t)
    if not t or type(t) ~= 'string' then
        return
    end
    if #t == 0 then
        return ''
    end
    return string.gsub(t, '<|(%w{%d,10})|>', '<| %1 |>')
end

return M
