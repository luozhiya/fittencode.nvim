--[[

]]

local Headless = require('fittencode.headless')
local Promise = require('fittencode.fn.promise')
local Log = require('fittencode.log')

local M = {}

local template = [[<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
Please infer and generate the commit message based on these differences.
Please note that the submission information should be succinct, and if there are more changes, please summarize them.
Answer only the content of the information to be submitted, do not provide additional answers.

## 任务
你是 Git Commit Message 生成专家。你的核心任务是在不破坏项目历史一致性的前提下，根据用户配置生成提交信息。

## 约束条件（最高优先级）
**严禁**使用任何预设的固定格式。
**必须**模仿下方提供的 [项目现有风格参考] 的写作习惯。

## 风格分析要求
在生成信息前，请先分析 [项目现有风格参考] 中的规律，包括但不限于：
1. **语言**：{{commit_message_preference}}
2. **动词时态**：过去式 (Fixed) 还是祈使句 (Fix)？
3. **首字母**：大写还是小写？
4. **标点符号**：句末是否有句号？是否使用 `:` 或 `-` 做分隔？
5. **长度**：大致是短标题（<50字符）还是详细描述？
6. **Emoji**：是否使用了特定表情符号（如 :bug: :sparkles:）？
7. **详略**: {{add_type_to_commit_message}}

## 输出要求
- 只输出**一条** Commit Message 文本（如果需要详细 Body，请另起一行空行后写）。
- 不要输出任何解释性文字，不要包含 Markdown 代码块标记（```），直接输出纯文本内容。
- 确保生成的文本混入上述 [项目现有风格参考] 中不会显得突兀。
<|end|>
<|user|>

## 项目现有风格参考
{{log}}

## 本次代码变更内容(patch)
```patch
{{patch}}
```

## 本次涉及文件的上下文
{{content}}

## 本次涉及修改处(hunks)的代码片段
{{sourcefragments}}
<|end|>
<|assistant|>]]

local commit_message_preference = {
    ['en'] = '忽略项目 Log 中的中文，输出**纯英文**',
    ['zh-cn'] = '忽略项目 Log 中的英文，输出**纯简体中文**',
    ['auto'] = '参考现有风格，纯英文、纯中文、还是中英混杂（如：“更新依赖 (Update Deps)”）？'
}

local add_type_to_commit_message = {
    ['concise'] = '生成精简的 **Title** 格式。不包含任何详细描述，只包含标题、动词',
    ['detailed'] = '生成标准的 **Title + Body** 结构。Body 部分用自然语言描述“为什么改”和“怎么改”，而不只是“改了什么”',
    ['auto'] = '**完全模仿** 现有的 Git Log 的风格',
}

---@return FittenCode.Protocol.Methods.ChatAuth.Payload
local function build_request_payload(options)
    local env = {
        patch = options.patch,
        log = options.log,
        commit_message_preference = options.language,
        add_type_to_commit_message = options.type,
        content = options.content,
        sourcefragments = options.sourcefragments,
    }
    return Headless.build_request_chat_payload(env, template)
end

---@return FittenCode.Promise<string, FittenCode.Error>, FittenCode.HTTP.Request?
function M.commit_message(options)
    local res, request = Headless.request_chat(build_request_payload(options))
    if not request then
        return Promise.rejected()
    end
    ---@param chunks string[]
    return res:forward(function(chunks)
        if #chunks == 0 then
            return Promise.rejected({ _msg = 'No response from server' })
        end
        return table.concat(chunks)
    end), request
end

return M
