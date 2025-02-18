--[[

基于 LSP 和 Tree-sitter 收集项目符号信息，并生成上下文提示
- 超时控制，如果 LSP 和 Tree-sitter 响应超时，则返回空
- 根据检索信息的类型，分为 Fast, Balance (default), Precise 三种模式
  - Fast 模式可能是指快速检索，牺牲一些准确性来提高响应速度。
  - Balance 模式可能是平衡模式，旨在在速度和准确性之间找到一个合理的折衷。
  - Precise 模式可能是指精确检索，需要较长时间来响应，但准确性较高。
- 有两种输出模式，分别对应 VSCode 中的 ProjectCompletionOld 和 ProjectCompletion

local sc = SemanticContext.new({ mode = 'fast', timeout = 1000, output_format = 'ProjectCompletion' })
local scold = SemanticContext.new({ mode = 'fast', timeout = 1000, output_format = 'ProjectCompletionOld' })

--]]

local ProjectCompletion = require('fittencode.inline.project_completion.versions.semantic_context.project_completion')

local SemanticContext = {}
SemanticContext.__index = SemanticContext

function SemanticContext.new(options)
    options = options or {}
    local self = setmetatable({}, SemanticContext)
    self:__initialize(options)
    return self
end

function SemanticContext:__initialize(options)
    self.mode = options.mode or 'balance'
    self.timeout = options.timeout or 1000
    self.output_format = options.output_format or 'ProjectCompletion'
    self.engine = ProjectCompletion.new()
end

function SemanticContext:generate_prompt(buf, position)
end

return SemanticContext
