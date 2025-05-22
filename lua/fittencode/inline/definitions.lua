local CONTROLLER_EVENT = {
    SESSION_ADDED = 'FittenCode.Inline.SessionAdded',
    SESSION_DELETED = 'FittenCode.Inline.SessionDeleted',
    SESSION_UPDATED = 'FittenCode.Inline.SessionUpdated',
    INLINE_DISABLED = 'FittenCode.Inline.Disabled',
    INLINE_RUNNING = 'FittenCode.Inline.Running',
    INLINE_IDLE = 'FittenCode.Inline.Idle',
}

local INLINE_STATUS = {
    IDLE = 'idle',
    DISABLED = 'disabled',
    RUNNING = 'running',
}

-- COMPLETION_STATUS 仅描述补全流程的进度（如请求中、建议就绪），属于会话交互阶段的子逻辑。
local COMPLETION_STATUS = {
    CREATED                    = 'created',                    -- 创建了 Session，COMPLETION
    GENERATING_PROMPT          = 'generating_prompt',          -- 正在构建补全请求的提示词（如代码片段、自然语言问题）。
    GETTING_COMPLETION_VERSION = 'getting_completion_version', -- 正在获取补全服务版本。
    GENERATE_ONE_STAGE         = 'generate_one_stage',         -- 向补全服务发送请求（如 HTTP 请求），等待响应。
    SUGGESTIONS_READY          = 'suggestions_ready',          -- 成功获取补全建议，可渲染到 UI。
    NO_MORE_SUGGESTIONS        = 'no_more_suggestions',        -- 补全服务返回无结果。
    ERROR                      = 'error',                      -- 补全流程失败（如网络错误、参数无效）。
}

-- 仅描述 Session 的生命周期（创建、初始化、交互、终止），不涉及补全细节。
local SESSION_LIFECYCLE = {
    CREATED = 'created',         -- 调用 Session.new() 后立即进入，仅完成实例化，未初始化任何资源。
    MODEL_READY = 'model_ready', -- 完成 Model 初始化
    INTERACTIVE = 'interactive', -- 会话正在处理补全或用户交互（对应补全流程中的活跃状态）。
    TERMINATED = 'terminated',   -- 会话永久结束，资源已释放（如网络请求取消、用户关闭补全）。
}

return {
    CONTROLLER_EVENT = CONTROLLER_EVENT,
    INLINE_STATUS = INLINE_STATUS,
    COMPLETION_STATUS = COMPLETION_STATUS,
    SESSION_LIFECYCLE = SESSION_LIFECYCLE,
}
