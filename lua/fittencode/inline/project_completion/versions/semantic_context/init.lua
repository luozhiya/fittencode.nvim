--[[

基于 LSP 和 Tree-sitter 收集项目符号信息，并生成上下文提示
- 超时控制，如果 LSP 和 Tree-sitter 响应超时，则返回空
- 根据检索信息的类型，分为 Fast, Balance (default), Precise 三种模式
  - Fast 模式可能是指快速检索，牺牲一些准确性来提高响应速度。
  - Balance 模式可能是平衡模式，旨在在速度和准确性之间找到一个合理的折衷。
  - Precise 模式可能是指精确检索，需要较长时间来响应，但准确性较高。
- 有两种输出模式，分别对应 VSCode 中的 ProjectCompletionOld 和 ProjectCompletion

Fast 模式：
- 仅使用 LSP 进行符号检索，尽量减少使用 Tree-sitter (限制文档大小)

local sc = SemanticContext.new({ mode = 'fast', timeout = 1000, format = 'vscode' })
local scold = SemanticContext.new({ mode = 'fast', timeout = 1000, format = 'vscode_old' })

--]]

--[[
// Below is partial code of /project/utils.js:
function calculate(a, b) {
  return a + b;
}

// Below is partial code of /project/main.js:
const result = calculate(3, 5);

// Below is partial code of /project/helper.ts:
interface Helper {
  id: number;
  name: string;
}
...
--]]

--[[
# Below is partical code of file:///src/user.py for the variable or function User::getName:
class User:
    def getName(self):  # Returns formatted user name
        ...
        return f"{self.last}, {self.first}"

# Below is partical code of file:///src/db/dao.py for the variable or function UserDAO::find_by_id:
class UserDAO:
    def find_by_id(self, uid):  # Core query method
        with self.conn.cursor() as cur:
            cur.execute("SELECT * FROM users WHERE id=%s", (uid,))
            ...
--]]

local Promise = require('fittencode.concurrency.promise')
local ProjectCompletion = require('fittencode.inline.project_completion.versions.semantic_context.project_completion')

local SemanticContext = {}
SemanticContext.__index = SemanticContext

function SemanticContext.new(options)
    options = options or {}
    local self = setmetatable({}, SemanticContext)
    self:__initialize(options)
    return self
end

-- FittenCode 可以平均在 200 ms 内完成补全，如果在获取 ProjectCompletion 阶段耗时太多就没有意义了
local MODE_TIMEOUT = {
    fast = 50,
    balance = 100,
    precise = 1000
}

function SemanticContext:__initialize(options)
    self.last_chosen_prompt_type = '0'
    self.mode = options.mode or 'balance'
    self.timeout = options.timeout or MODE_TIMEOUT[self.mode]
    self.format = options.format or 'vscode'
    self.engine = ProjectCompletion.new(self.mode, self.format)
end

-- 异步获取项目级别的 Prompt
-- resolve: 超时返回 nil，否则返回提示内容
-- reject: 超时返回
---@return FittenCode.Concurrency.Promise
function SemanticContext:generate_prompt(buf, position)
    return Promise.race({
        Promise.async(function(resolve, reject)
            local result = self.engine:get_prompt(buf, position)
            resolve(result)
        end),
        Promise.delay(self.timeout)
    })
end

return SemanticContext
