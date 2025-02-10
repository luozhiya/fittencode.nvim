local END_OF_TEXT_TOKEN = '<|endoftext|>' -- 文本结束标记

local ResponseParser = {}
ResponseParser.__index = ResponseParser

function ResponseParser:new()
    return setmetatable({}, self)
end

-- 这是 Vim 版本的代码补全数据
-- * 只需要处理一个 generated_text
function ResponseParser:parse(raw)
    local generated_text = vim.fn.substitute(raw.generated_text, END_OF_TEXT_TOKEN, '', 'g') or ''
    if generated_text == '' then
        return
    end
    return {
        completions = {
            {
                generated_text = generated_text,
            },
        },
    }
end

return {
    ResponseParser = ResponseParser,
}
