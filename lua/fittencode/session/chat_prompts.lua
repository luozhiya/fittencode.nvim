local VM = require('fittencode.vm')

local M = {}

---@param text? string|string[]
function M.word_segmentation(text)
    local fmttext = {}
    if type(text) == 'string' then
        fmttext = { text }
    elseif type(text) == 'table' then
        fmttext = text
    end
    assert(#fmttext > 0, 'text should not be empty')
    local messages = {}
    for idx, t in ipairs(fmttext) do
        local lines = ''
        lines = lines .. '# ' .. idx .. '\n'
        lines = lines .. '\n```\n'
        lines = lines .. t .. '\n'
        lines = lines .. '```\n\n'
        messages[idx] = {
            content = lines,
        }
    end
    local template = [[<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
请完全使用中文回答。
<|end|>
<|user|>
请对下面的几段原文分别进行语义分词（Incorporate Semantic），按如下2个要求来执行：
1. 严禁对原文字符做任何修改，包括标点符号。分词结果concat合并起来要和原文完全相等
2. 输出json格式的分词向量，一级标题作为key，json为一个完整对象

{{#each messages}}
{{content}}
{{/each}}

<|end|>
<|assistant|>]]
    local env = {
        messages = messages,
    }
    local inputs = assert(VM:new():run(env, template))
    return {
        inputs = inputs,
        ft_token = M.get_ft_token(),
        meta_datas = {
            project_id = '',
        }
    }
end

return M
