local VM = require('fittencode.vm')
local Client = require('fittencode.client')

local M = {}

---@param text? string|string[]
function M.word_segmentation(text)
    if not text then
        return
    end

    ---@type string[]
    ---@diagnostic disable-next-line: assign-type-mismatch
    text = (type(text) == 'string') and { text } or text

    local messages = {}
    for idx, t in ipairs(text) do
        assert(t and t ~= '', 'content should not be empty')
        messages[idx] = {
            content = string.format('# %d\n\n```\n%s\n```\n\n', idx, t)
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
    local api_key_manager = Client.get_api_key_manager()

    return {
        inputs = inputs,
        ft_token = api_key_manager:get_fitten_user_id() or '',
        meta_datas = {
            project_id = '',
        }
    }
end

return M
