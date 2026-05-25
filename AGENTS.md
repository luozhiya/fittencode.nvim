# AGENTS.md — FittenCode Chat 开发指引

## 项目概览

FittenCode 是一个 Neovim AI 编程助手插件。chat 子系统对标 VSCode 版 Fitten Code，实现 NDJSON 流式对话、多会话切换、本地模板引擎。

**关键参考文件**:
- `turns.md` — 完整开发迭代记录（12 轮）
- `new_chat.md` — 初始设计文档
- VSCode 插件反混淆分析（extension.js 中 `ChatController`, `Conversation`, `ChatModel` 等）

## 代码库约定

### 类模式
全部使用 `{} + setmetatable({}, T) + T.__index = T` 模式。`new()` 构造, `:_initialize()` 内部初始化。

```lua
local M = {}
M.__index = M
function M.new(options)
    local self = setmetatable({}, M)
    self:_initialize(options)
    return self
end
function M:_initialize(options) ... end
```

### 方法调用
- 定义在类上的方法用 `:` 调用 (`self:answer()`)
- 外部注入的回调函数用 `.` 调用 (`self.update_view()`, `self.send_msg()`)
- **绝对不能混淆**：冒号调用平面函数会把 `self` 作为隐式第一参数（Turn 3 bug）

### 日志
使用 `require('fittencode.log')`，占位符 `{}`：

```lua
local Log = require('fittencode.log')
Log.debug('[Chat.Module] message key={} value={}', k, v)
Log.error('[Chat.Module] error reason')
```

日志级别由 `Config.log.level` 控制（默认 WARN，开发用 DEBUG）。

### Observer 模式
从 `inline/controller.lua:163-184` 借鉴的简洁模式：

```lua
function Controller:on(observer)
    table.insert(self.observers, observer)
end

function Controller:emit(data)
    for _, obs in ipairs(self.observers) do
        if type(obs) == 'function' then obs(data)
        elseif obs.update then obs:update(data) end
    end
end
```

Observer 签名统一为 `update(data)`。`data` 结构：

```lua
{
    ctrl = 'idle' | 'running',
    current_conversation_id = 'xxx',
    conversation = { id, phase, state }
}
```

## 文件结构与职责

```
lua/fittencode/chat/
├── init.lua                          # 入口: 组装 + 命令/键位
├── controller.lua                    # 总控: receive_msg 分发 + update_view
├── ctrl_observer.lua                 # StatusObserver + ProgressIndicatorObserver
├── conversation.lua                  # 核心: 状态机 + HTTP 流 + abort
├── conversation_type.lua             # 工厂: Template → Conversation
├── conversation_types_provider.lua   # 模板加载 (内置/扩展/工作区)
├── model.lua                         # 会话列表 (max 100, selected_conversation_id)
├── builtin_templates.lua             # 模板清单 + TEMPLATE_CATEGORIES 映射
├── template_resolver.lua             # .rdt.md treesitter 解析
├── _types.lua                        # LuaLS 类型标注
└── view/
    ├── init.lua                      # UI 渲染 + 输入 + 窗口管理
    └── state.lua                     # Model → ViewState 序列化
```

### 依赖链

```
init.lua
  ├── Controller
  │     ├── Model
  │     ├── View
  │     │     ├── State
  │     │     └── msg_buf / inp_buf / ref_buf (neovim buffers)
  │     ├── ConversationTypesProvider
  │     │     ├── ConversationType
  │     │     ├── TemplateResolver
  │     │     └── builtin_templates
  │     └── CtrlObserver (StatusObserver, ProgressIndicatorObserver)
  └── Conversation ←── Controller 创建的每个会话
```

## 核心设计决策

### 两层消息（对齐 VSCode）

**View → Controller**: `receive_msg(msg)` 接收 `{ type, data }`：
- `send_message` → conv:answer()
- `start_chat` → create_conversation()
- `select_conversation` / `delete_conversation` → model 操作
- `stop_waiting` → conv:stop_waiting()

**Controller → View**: `update_view()` → 序列化 Model → `view:update(state)`

不存在 observer 参与核心数据流。Conversation/View 不依赖 observer。

### 状态机 (Conversation)

```
userCanReply
    │ answer(content)
    │   → add_user_message → state='waitingForBotAnswer' → update_view()
    │   → execute_chat()
    ▼
waitingForBotAnswer
    │ stream:on('data') 首次到达
    │   → state='botAnswerStreaming' → update_view()
    ▼
botAnswerStreaming
    │ 每个 chunk → update_partial_bot_message → update_view()
    │ async():then()
    │   → add_bot_message → state='userCanReply' → update_view()
    ▼
userCanReply ← 循环
```

中止: `stop_waiting()` → `request_handle:abort()` → 直接设 `state='userCanReply'`。

### NDJSON 流解析

HTTP 响应 body 是 NDJSON（一行一个 JSON），不是 SSE。`http.lua` 底层用 curl spam。

```lua
stream:on('data', vim.schedule_wrap(function(chunk_data)
    local lines = vim.split(chunk_data.chunk, '\n', { trimempty = true })
    for _, line in ipairs(lines) do
        local ok, chunk = pcall(vim.json.decode, line)
        if ok and chunk and chunk.delta and validate_delta(delta) then
            completion[#completion+1] = delta
            self:update_partial_bot_message(table.concat(completion, ''))
        end
    end
end))
```

过滤条件: `is_heartbeat(delta)` 跳过 keep-alive，`validate_delta(delta)` 跳过含 null byte 的 reset 信号。

### View 渲染

**Msg buffer**: `filetype='markdown'`，`modifiable=false`。渲染时临时 `modifiable=true`，写完后恢复。

**流式渲染**（避免 40 次/秒洪水）:
```lua
function View:_render_streaming(partial)
    if self.streaming_pending then return end  -- 跳过快照
    self.streaming_pending = true
    vim.schedule(function()
        self.streaming_pending = false
        self:_do_render_streaming(partial)
    end)
end
```

首帧: 追加 `## Fitten Code` + 空行，记录 `streaming_anchor = { row, 0 }`。
后续帧: `nvim_buf_set_text(buf, anchor.row, anchor.col, -1, -1, lines)` 原地替换。

**流式结束过渡**: `was_streaming` 标记。当 `state.type` 从 `botAnswerStreaming` 变非 streaming 时，只同步 `last_msg_count`，不重绘——流式内容已在 buffer 中。

### Pending 队列

状态非 `userCanReply` 时 Enter 的内容暂存，流式结束后自动发送。

**关键约束**: 每次 `_show_pending` 必须关闭旧窗口重建（`relative='win'` 的 `row` 在 `set_config` 中不可靠，向下增长会覆盖 input）。

**`<CR>` 回调顺序**: 先清空 input → 再判断 pending/发送。不能先 send 后清空（`send_msg` → `update_view` 同步链可能改变 buffer 状态）。

### 模板系统

`.rdt.md` 文件用 treesitter markdown parser 解析。格式：
```
## Template
### Configuration
```json { id, engineVersion, label, header, variables, initialMessage?, response }
```
### Response Prompt
```template-response
<|system|>...<|end|><|user|>...<|end|>...
```
```

`ConversationTypesProvider` 按 builtin → extension → workspace 优先级加载。模板 ID 格式：`{category}-{lang}` 如 `chat-en`，`create_conversation()` 自动追加语言后缀（先 `-{display_preference}`，fallback `-en`）。

## 扩展指南

### 添加新的用户动作 msg type

1. `controller.lua:receive_msg()` 添加 `elseif msg.type == 'new_type' then`
2. `view/init.lua:_setup_input()` 或其他触发点调用 `self.send_msg({ type = 'new_type', data = {...} })`

### 添加新的会话消息处理

在 `controller.lua:_build_observer_data()` 或 `update_view()` 流程中附加新字段。state 结构定义在 `view/state.lua:get_state_from_model()`。

### 添加模板

1. 在 `template/chat/` 或 `template/task/` 放入 `.rdt.md`
2. 在 `builtin_templates.lua` 的 `builtin_templates` 表中注册文件名

### 修改 pcall → pcall(fn) 保护

当前关键路径无 pcall 保护。如果遇到静默崩溃，先在 `receive_msg` / `<CR>` 回调包裹 pcall。

## 已知问题 / TODO

| 项 | 状态 | 位置 |
|---|---|---|
| 选区添加上下文 | 未实现 | `controller:add_selection_context_to_input()` 回调空 |
| inline 补全过滤 chat buffer | 未实现 | 需改 `inline/controller.lua` 的 `trigger_inline_suggestion()` |
| 会话持久化 | 未实现 | 纯内存，重启丢失 |
| @workspace RAG | 未实现 | `conversation:execute_chat()` 中有 rag 路由框架，但未触发 |
| Agent pipeline | 未实现 | JS 版有 ProjectAgent/ReferenceAgent/ApplyAgent，当前只做字符串拼接 |
| `should_enable(buf)` 过滤 | 未接入 | `inline/controller.lua:271` 需加一行检查 |
| `reloadChatBreaker` (5h 超时) | 未实现 | JS 版有此功能 |

## 调试

**查看日志**: `tail -f ~/.local/state/nvim/fittencode/fittencode.log | grep '\[Chat\.'`

**关键日志点**:
- `[Chat.View]` — Enter 检测、send_msg 调用、渲染路径
- `[Chat.Controller]` — receive_msg 分发、update_view
- `[Chat.Conv]` — answer、execute_chat、stream data/completion、stop_waiting

**常见问题**:
- Enter 无反应 → 检查 `send_msg` 是否已绑定（`.send_msg()` 非 `:send_msg()`）
- 回复重复 → 检查 `was_streaming` 过渡逻辑
- pending 覆盖 input → 检查 `_show_pending` 是否先 `_hide_pending` 重建
