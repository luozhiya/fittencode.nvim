local CONTROLLER_EVENT = {
    SESSION_ADDED   = 'session_added',
    SESSION_DELETED = 'session_deleted',
    SESSION_UPDATED = 'session_updated',
    INLINE_DISABLED = 'inline_disabled',
    INLINE_RUNNING  = 'inline_running',
    INLINE_IDLE     = 'inline_idle',
}
---@alias FittenCode.Inline.ControllerEvent.Type 'session_added' |'session_deleted' |'session_updated' | 'inline_disabled' | 'inline_running' | 'inline_idle'

local INLINE_EVENT = {
    IDLE     = 'idle',
    DISABLED = 'disabled',
    RUNNING  = 'running',
}
---@alias FittenCode.Inline.InlineEvent.Type 'idle' | 'disabled' | 'running'

-- COMPLETION_STATUS 仅描述一次标准补全流程的进度（如请求中、建议就绪），属于会话交互阶段的子逻辑。
local COMPLETION_EVENT = {
    START                      = 'start',                      -- 创建了 Session，COMPLETION
    GENERATING_PROMPT          = 'generating_prompt',          -- 正在构建补全请求的提示词（如代码片段、自然语言问题）。
    GETTING_COMPLETION_VERSION = 'getting_completion_version', -- 正在获取补全服务版本。
    GENERATE_ONE_STAGE         = 'generate_one_stage',         -- 向补全服务发送请求（如 HTTP 请求），等待响应。
    SUGGESTIONS_READY          = 'suggestions_ready',          -- 成功获取补全建议，可渲染到 UI。
    NO_MORE_SUGGESTIONS        = 'no_more_suggestions',        -- 补全服务返回无结果。
    ERROR                      = 'error',                      -- 补全流程失败（如网络错误、参数无效）。
}
---@alias FittenCode.Inline.CompletionEvent.Type 'start' | 'generating_prompt' | 'getting_completion_version' | 'generate_one_stage' |'suggestions_ready' | 'no_more_suggestions' | 'error'

-- 在标准 Completion 之外，Session 还会执行一些额外的任务，如语义分割（如中文分词）。
local SESSION_TASK_EVENT = {
    SEMANTIC_SEGMENT_PRE  = 'semantic_segment_pre',  -- 开始语义分割（如中文分词）
    SEMANTIC_SEGMENT_POST = 'semantic_segment_post', -- 完成语义分割
}
---@alias FittenCode.Inline.SessionTaskEvent.Type'semantic_segment_pre' |'semantic_segment_post'

-- 仅描述 Session 的生命周期（创建、初始化、交互、终止），不涉及补全细节。
local SESSION_EVENT = {
    CREATED     = 'created',     -- 调用 Session.new() 后立即进入，仅完成实例化，未初始化任何资源。
    REQUESTING  = 'requesting',  -- 正在请求补全服务，等待响应。
    MODEL_READY = 'model_ready', -- 完成 Model 初始化
    INTERACTIVE = 'interactive', -- 会话正在处理补全或用户交互（对应补全流程中的活跃状态）。
    TERMINATED  = 'terminated',  -- 会话永久结束，资源已释放（如网络请求取消、用户关闭补全）。
}
---@alias FittenCode.Inline.SessionEvent.Type 'created' |'requesting' |'model_ready' | 'interactive' | 'terminated'

return {
    CONTROLLER_EVENT = CONTROLLER_EVENT,
    INLINE_EVENT = INLINE_EVENT,
    COMPLETION_EVENT = COMPLETION_EVENT,
    SESSION_TASK_EVENT = SESSION_TASK_EVENT,
    SESSION_EVENT = SESSION_EVENT,
}
