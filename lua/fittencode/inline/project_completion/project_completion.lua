--[[

基于 LSP 和 Tree-sitter 收集项目符号信息，并生成上下文提示
- 超时控制，如果 LSP 和 Tree-sitter 响应超时，则返回空
- 根据检索信息的类型，分为 Fast, Balance (default), Precise 三种模式
  - Fast 模式可能是指快速检索，牺牲一些准确性来提高响应速度。
  - Balance 模式可能是平衡模式，旨在在速度和准确性之间找到一个合理的折衷。
  - Precise 模式可能是指精确检索，需要较长时间来响应，但准确性较高。
- 有两种输出模式，分别对应 VSCode 中的 ProjectCompletionOld 和 ProjectCompletion

模式预先设计如下，具体实现还需要根据实际情况进行调整：

Fast 模式：
- 仅使用 LSP 进行符号检索，尽量减少使用 Tree-sitter (限制文档大小)
- LSP
    - { 'textDocument/definition', 'textDocument/typeDefinition' }
- Tree-sitter
    - < 1000 characters
    - 捕获当前符合的最大range，不做更细的分析

Balance 模式：
- 使用 LSP 进行符号检索，放开 Tree-sitter 的限制，但仍然会有一些限制
- { 'textDocument/definition', 'textDocument/typeDefinition', 'textDocument/references', 'textDocument/documentSymbol' }
- Tree-sitter
    - < 10000 characters
    - 捕获当前符合的最大range，并分析其范围内的符号

Precise 模式：
- 使用 LSP 进行符号检索，放开 Tree-sitter 的限制
- { 'textDocument/definition', 'textDocument/typeDefinition', 'textDocument/references', 'textDocument/documentSymbol', 'textDocument/implementation' }

local sc = SemanticContext.new({ mode = 'fast', timeout = 1000, format = 'file' })
local scold = SemanticContext.new({ mode = 'fast', timeout = 1000, format = 'identifier' })

--]]

local Promise = require('fittencode.concurrency.promise')
local SemanticContext = require('fittencode.inline.project_completion.semantic_context')
local Config = require('fittencode.config')

local ProjectCompletion = {}
ProjectCompletion.__index = ProjectCompletion

function ProjectCompletion.new(options)
    local self = setmetatable({}, ProjectCompletion)
    self:__initialize(options)
    return self
end

-- FittenCode 可以平均在 200 ms 内完成补全，如果本地在获取 ProjectCompletion Prompt 阶段耗时太多就没有意义了
local MODE_TIMEOUT = {
    fast = 50,
    balance = 100,
    precise = 1000
}

function ProjectCompletion:__initialize(options)
    options = options or {}
    self.get_chosen = options.get_chosen
    assert(self.get_chosen, 'get_chosen is required')
    self.mode = options.mode or 'balance'
    self.timeout = options.timeout or MODE_TIMEOUT[self.mode]
    self.format = options.format or 'file'
    self.semantic_context = SemanticContext.new(self.mode, self.format)
end

-- 是否可以进行 Project Completion
-- * resolve 返回 pc_prompt_type
-- * reject 失败
---@return FittenCode.Concurrency.Promise
function ProjectCompletion:preflight()
    local open = Config.use_project_completion.open
    if open == 'auto' or open == 'on' then
        return self.get_chosen()
    end
    return Promise.reject()
end

-- * resolve: 超时返回 nil，否则返回提示内容
-- * reject: 出错
---@return FittenCode.Concurrency.Promise
function ProjectCompletion:generate_prompt(buf, position)
    return Promise.race({
        self:preflight():forward(function(chosen)
            return Promise.async(function(resolve, reject)
                local prompt = self.semantic_context:get_prompt_sync(buf, position, {
                    order = chosen == '3' and 'reversed' or 'forward',
                })
                local meta = {
                    pc_available = true,
                    pc_prompt = prompt,
                    pc_prompt_type = chosen
                }
                resolve(meta)
            end)
        end),
        Promise.delay(self.timeout)
    })
end

return ProjectCompletion
