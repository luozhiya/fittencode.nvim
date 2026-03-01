--[[

- 不同的编辑器采用了不同的类型名称，比如 .txt 在 vscode 中叫做 `Plain Text` ，而在 vim 中叫做 "text"
- 因此，只返回后缀

]]

local Generate = require('fittencode.generate')
local Promise = require('fittencode.fn.promise')
local Log = require('fittencode.log')

local M = {}

local template = [[<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
<|end|>
<|user|>
请严格按以下流程分析代码：
1. **语法特征分析**：识别代码中的独特语法（ 如特殊符号、关键字、注释格式、结构特征 ）
2. **环境线索提取**：检查是否存在环境声明（ 如shebang、@requires ）或框架标识
3. **类型推理**：基于特征匹配常见文件类型，优先级：
   - 编程语言（ Python→py, Rust→rs, Scheme→scm, Java→java, C++→cpp, Go→go, JavaScript→js, TypeScript→ts ）
   - 配置文件（ YAML→yaml, JSON→json ）
   - 脚本文件（ Shell→sh, PowerShell→ps1 ）
   - 标记语言（ HTML→html, XML→xml ）
   - 复合文档（ Markdown→md, RST→rst, txt→txt ）
4. **后缀确定规则**：
   - 优先采用最主流后缀（JavaScript→js）
   - 有编译要求时区分扩展名（C→c, C++→cpp）
   - 配置文件带类型前缀（docker-compose.yml→yml）
5. **输出规则**：
   - 返回标准文件后缀名（ 不带点 ）
   - 如果文件类型没有后缀时返回该文件名（ Dockerfile→Dockerfile ）
   - 完全无法识别则返回空字符

待分析代码：
```
{{code}}
```
<|end|>
<|assistant|>]]

---@param text string
---@return FittenCode.Protocol.Methods.ChatAuth.Payload
local function build_request_payload(text)
    assert(text)
    local env = {
        code = text,
    }
    return Generate.build_request_chat_payload(env, template)
end

---@param text string
---@return FittenCode.Promise<string, FittenCode.Error>, FittenCode.HTTP.Request?
function M.send_filetype(text)
    local res, request = Generate.request_chat(build_request_payload(text))
    if not request then
        return Promise.rejected()
    end
    ---@param chunks string[]
    return res:forward(function(chunks)
        if #chunks == 0 then
            return Promise.rejected({ message = 'No response from server' })
        end
        return table.concat(chunks)
    end), request
end

return M
