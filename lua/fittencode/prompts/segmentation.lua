local VM = require('fittencode.open_promot_language.vm')
local Client = require('fittencode.client')

local M = {}

---@param text? string|string[]
function M.generate(text)
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
请对下面的几段原文分别进行语义分词（Incorporate Semantic），按如下3个要求来执行：
1. 严禁对原文字符做任何修改，包括标点符号。分词结果concat合并起来要和原文完全相等
2. 输出json格式的分词向量，一级标题作为key，json为一个完整对象
3. 空格与换行符等特殊字符要保留，不要去掉，也算作一个词，如果是连续的特殊符号，要看上下文确定是否合并成一个词。

示例如下，示例中用 "原文begin" 和 "原文end" 分隔原文，用 "输出begin" 和 "输出end" 分隔输出。

原文begin
# 1

```
我吃苹果
```

# 2

```
```

# 3

```
明天  会下雨
嗯
```

原文end

输出begin
{
    "1" : ["我", "吃", "苹果"],
    "2" : [],
    "3" : ["明天", "  ",  "会", "下雨"， "\n", "嗯"]
}
输出end

原文:

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
