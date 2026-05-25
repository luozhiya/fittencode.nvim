# FittenCode Chat 实现方案

> 基于 VSCode 插件 extension.js 的反混淆分析，参考旧 neovim 实现，适配新代码库架构。

## 一、架构总览

```
┌──────────────────────────────────────────────────────────┐
│  View (view/init.lua)                                    │
│  ┌── update(state) ←── Controller:update_view()          │
│  └── send_msg(msg) ──→ Controller:receive_msg(msg)       │
│  职责: buffer 渲染 + 用户输入                             │
└──────────────────────────┬───────────────────────────────┘
                           │  state          │  msg
┌──────────────────────────┴─────────────────┴─────────────┐
│  Controller (controller.lua)                              │
│  ┌── receive_msg(msg): 路由到 Conversation / Model        │
│  ├── update_view(): 序列化 Model → state → View:update    │
│  └── on/emit: observer 侧通道 ──────────┐                 │
└─────────────────────────────────────────┼─────────────────┘
                           │  update_view callback          │
┌──────────────────────────┴───────────────────────────────┐
│  Conversation (conversation.lua) - 核心                   │
│  ┌── answer() → add_user_message → update_view()          │
│  │            → execute_chat (stream:on data → update)    │
│  └── stop_waiting() → abort + 恢复                     │
│  职责: 消息存储、状态机、HTTP 流、中断                     │
└──────────────────────────────────────────────────────────┘

Observer 侧通道（独立于核心流）:
  Controller:on/emit ─→ StatusObserver     (get_snapshot API)
                     ─→ ProgressIndicatorObserver (pi:start/stop)
  Controller 在 update_view() 前 emit
```

## 二、文件结构

```
lua/fittencode/chat/
├── init.lua                       # 入口: 组装 + 注册命令/键位/菜单
├── controller.lua                 # receive_msg + update_view + on/emit
├── ctrl_observer.lua              # StatusObserver + ProgressIndicatorObserver
├── conversation.lua               # 核心: 状态机 + messages[] + execute_chat + abort
├── conversation_type.lua          # 工厂: Template → Conversation
├── conversation_types_provider.lua # 模板加载: builtin/extension/workspace
├── model.lua                      # 会话列表 (max 100, selected_conversation_id)
├── builtin_templates.lua          # 内置模板定义
├── template_resolver.lua          # .rdt.md 解析
├── _types.lua                     # 类型标注 (LuaLS annotations)
└── view/
    ├── init.lua                   # UI: 稳定 buffer 渲染 + 输入 + 窗口管理
    └── state.lua                  # Model → 序列化 ViewState
```

## 三、两层消息（与 VSCode 对齐）

### 3.1 View → Controller (用户动作)

`Controller:receive_msg(msg)` 路由表：

```lua
'send_message'          → conv:answer(msg.data.message)
'start_chat'            → create_conversation(basic_chat_template_id)
'select_conversation'   → model.selected_conversation_id = msg.data.id
                        → view:select_conversation(msg.data.id)
                        → update_view()
'stop_waiting'          → conv:stop_waiting()
'delete_conversation'   → model:delete_conversation(msg.data.id)
                        → update_view()
```

### 3.2 Controller → View (状态同步)

`Controller:update_view()` → `View:update(state)`:

```lua
state = {
    selected_conversation_id = 'xxx',
    conversations = {
        ['id1'] = {
            id = 'xxx',
            header = {
                title = 'Chat Title',
                is_title_message = false,
                codicon = 'comment-discussion'
            },
            content = {
                type = 'messageExchange',
                messages = {
                    { author = 'user', content = 'hello' },
                    { author = 'bot', content = 'Hi there!' },
                },
                state = {
                    type = 'userCanReply'
                         | 'waitingForBotAnswer'
                         | 'botAnswerStreaming',
                    partialAnswer = '...'  -- 仅 streaming 时存在
                },
                error = nil  -- 发生错误时含错误信息
            },
            timestamp = '2025-01-01 12:00:00',
            is_favorited = false,
            mode = 'chat'
        }
    }
}
```

## 四、Conversation 核心 (conversation.lua)

### 4.1 构造与依赖

```lua
function Conversation.new(options)
    self.id = options.id
    self.template = options.template      -- 模板定义（含 header, variables, response template 等）
    self.init_variables = options.init_variables
    self.messages = {}                    -- { author, content }[]
    self.state = { type = 'userCanReply' }
    self.error = nil
    self.abort_before_answer = false      -- stop_waiting 时置 true，阻止 add_bot_message

    -- 唯一向外回调
    self.update_view = options.update_view  -- → Controller:update_view()

    -- 网络层
    self.request_handle = nil             -- HTTP Request handle, 用于 abort
end
```

### 4.2 状态机

```
userCanReply
    │  answer(content)
    │  → add_user_message → state = 'waitingForBotAnswer' → update_view()
    │  → execute_chat
    ▼
waitingForBotAnswer
    │  stream:on('data') 首次到达
    │  → state = 'botAnswerStreaming' → update_view()
    ▼
botAnswerStreaming
    │  每次 data chunk → update_view()  （partialAnswer 不断增长）
    │  async():then() 完成
    │  → add_bot_message → state = 'userCanReply' → update_view()
    ▼
userCanReply  ← 循环
```

中断路径（任意时刻）:
```
stop_waiting()
    → abort_before_answer = true
    → request_handle:abort()
    → push 取消消息
    → state = 'userCanReply' → update_view()
```

### 4.3 execute_chat 流程

```lua
function Conversation:execute_chat()
    -- 1. 解析最后一条消息，判断是否 @workspace
    local last_msg = self.messages[#self.messages]?.content
    local is_rag = last_msg and last_msg:match('^@_?workspace')

    -- 2. 模板求值
    local ir = self.messages[1] == nil
        and self.template.initialMessage
        or self.template.response
    local variables = self:resolve_variables_at_message_time()
    local inputs = OPL.run(variables, ir.template)

    -- 3. 构建 payload
    local payload = {
        inputs = inputs,
        ft_token = api_key_manager:get_fitten_user_id() or '',
        meta_datas = { project_id = '' }
    }

    -- 4. 发请求 (带 auth, 自动处理 401 refresh)
    local protocol = is_rag
        and Protocol.Methods.rag_chat
        or Protocol.Methods.chat_auth
    self.request_handle = Client.make_request_auth(protocol, {
        payload = vim.json.encode(payload)
    })
    if not self.request_handle then
        self:set_error('Failed to create request')
        return
    end

    -- 5. 流式解析 NDJSON
    local completion = {}
    self.request_handle.stream:on('data', vim.schedule_wrap(function(chunk_data)
        local lines = vim.split(chunk_data.chunk, '\n', { trimempty = true })
        for _, line in ipairs(lines) do
            local ok, chunk = pcall(vim.json.decode, line)
            if ok and chunk and chunk.delta then
                if not self:_validate_delta(chunk.delta) then
                    -- 跳过含 \0 字节的 delta（reset 信号）
                    goto continue
                end
                completion[#completion + 1] = chunk.delta

                -- 处理标记: =====REFERENCES====== / =====RESPONSE======
                -- （第一版简化，不做 agent pipeline，直接拼接）
                self:update_partial_bot_message(table.concat(completion, ''))
            end
            ::continue::
        end
    end))

    -- 6. 完成处理
    self.request_handle:async():forward(function()
        self:add_bot_message(table.concat(completion, ''))
    end):catch(function(err)
        if err and err ~= 'stop' then
            self:set_error(err._msg or 'Unknown error')
        end
    end)
end
```

### 4.4 _validate_delta

与 VSCode 一致，排除含 null byte 的 delta（`\0\0\0\0\0\0\0\0\n\n` 是 reset 信号）:

```lua
function Conversation:_validate_delta(delta)
    for i = 1, #delta do
        if string.byte(delta, i) == 0 then
            return false
        end
    end
    return true
end
```

### 4.5 stop_waiting

```lua
function Conversation:stop_waiting()
    self.abort_before_answer = true
    if self.request_handle then
        self.request_handle:abort()  -- → http.lua → Process:kill('sigterm')
        self.request_handle = nil
    end
    if self.state.type == 'waitingForBotAnswer' then
        self:add_bot_message('⚠ Response was cancelled by the user.')
    end
end

function Conversation:add_bot_message(content)
    if self.abort_before_answer then
        self.abort_before_answer = false
        return
    end
    self.messages[#self.messages + 1] = { author = 'bot', content = content }
    self.state = { type = 'userCanReply' }
    self:update_view()
end
```

## 五、Controller (controller.lua)

### 5.1 构造

```lua
function Controller.new(options)
    self.view = options.view
    self.model = options.model
    self.basic_chat_template_id = options.basic_chat_template_id
    self.conversation_types_provider = options.conversation_types_provider

    -- Observer 侧通道
    self.observers = {}
    self:on(StatusObserver.new())
    self:on(ProgressIndicatorObserver.new({ pi = ProgressIndicator.new() }))
end
```

### 5.2 核心方法

```lua
-- View → Controller
function Controller:receive_msg(msg)
    if msg.type == 'send_message' then
        self.model:get_by_id(msg.data.id):answer(msg.data.message)
    elseif msg.type == 'start_chat' then
        self:create_conversation(self.basic_chat_template_id)
    elseif msg.type == 'select_conversation' then
        self.model.selected_conversation_id = msg.data.id
        self.view:select_conversation(msg.data.id)
        self:update_view()
    elseif msg.type == 'stop_waiting' then
        self.model:get_by_id(msg.data.id):stop_waiting()
    elseif msg.type == 'delete_conversation' then
        self.model:delete_conversation(msg.data.id)
        self:update_view()
    end
end

-- Model → View
function Controller:update_view()
    local state = State.get_state_from_model(self.model)
    -- emit observer data（在 view update 之前）
    self:emit({
        ctrl = self:_derive_ctrl_state(),
        current_conversation_id = self.model.selected_conversation_id,
        conversation = self:_derive_conversation_data(),
    })
    self.view:update(state)
end

-- 从 model/conv 派生 observer 需要的数据
function Controller:_derive_conversation_data()
    local conv = self.model:get_by_id(self.model.selected_conversation_id)
    if not conv then return nil end
    local phase
    if conv.request_handle and conv.state.type == 'botAnswerStreaming' then
        phase = 'streaming'
    elseif conv.request_handle and conv.state.type == 'waitingForBotAnswer' then
        phase = 'make_request'
    elseif conv.state.type == 'userCanReply' then
        phase = 'completed'
    end
    return { id = conv.id, phase = phase, state = conv.state }
end
```

### 5.3 Observer 通道

```lua
function Controller:on(observer)
    table.insert(self.observers, observer)
end

function Controller:emit(data)
    for _, obs in ipairs(self.observers) do
        if type(obs) == 'function' then
            obs(data)
        elseif obs.update then
            obs:update(data)
        end
    end
end
```

### 5.4 create_conversation

```lua
function Controller:create_conversation(template_id, show, mode)
    show = show ~= false
    mode = mode or 'chat'

    local conv_type = self.conversation_types_provider:get_by_id(template_id)
    local variables = self:_resolve_variables(conv_type.template.variables, { time = 'conversation-start' })

    local result = conv_type:create_conversation({
        conversation_id = Fn.generate_short_id(9),
        template_id = template_id,
        init_variables = variables,
        update_view = function() self:update_view() end,
        resolve_variables = function(ctx, vars, event) return self:_resolve_variables(ctx, vars, event) end,
    })

    if result.type == 'unavailable' then
        vim.notify(result.message or 'Required input unavailable', vim.log.levels.ERROR)
        return
    end

    result.conversation.mode = mode
    self:add_and_show_conversation(result.conversation, show)

    if result.should_immediately_answer then
        result.conversation:answer()
    end
end
```

## 六、ctrl_observer.lua

### 6.1 StatusObserver

```lua
function StatusObserver.new()
    self.current = { ctrl = 'idle', conversation_id = nil, conversation_state = nil }
end

function StatusObserver:update(data)
    if data.ctrl then
        self.current.ctrl = data.ctrl
    end
    if data.conversation and data.current_conversation_id == data.conversation.id then
        self.current.conversation_id = data.conversation.id
        self.current.conversation_state = data.conversation.state
    else
        self.current.conversation_id = nil
        self.current.conversation_state = nil
    end
end

function StatusObserver:get_snapshot()
    return vim.deepcopy(self.current)
end
```

### 6.2 ProgressIndicatorObserver

```lua
function ProgressIndicatorObserver.new(options)
    self.pi = options.pi
    self.start_time = nil
end

function ProgressIndicatorObserver:update(data)
    vim.schedule(function()
        if data.ctrl ~= 'running' or not data.conversation then
            self.pi:stop()
            self.start_time = nil
            return
        end
        local phase = data.conversation.phase
        if phase == 'streaming' or phase == 'make_request' then
            if not self.start_time then
                self.start_time = vim.uv.hrtime()
                self.pi:start(self.start_time)
            end
        else
            self.pi:stop()
            self.start_time = nil
        end
    end)
end
```

## 七、Model (model.lua)

与 VSCode ChatModel 对齐：

```lua
function Model.new()
    self.conversations = {}        -- Conversation[]
    self.selected_conversation_id = nil
end

function Model:add_and_select_conversation(conv)
    -- 弹出上一个空会话
    if #self.conversations > 0 then
        local last = self.conversations[#self.conversations]
        if last and #last.messages == 0 then
            table.remove(self.conversations)
        end
    end
    -- 最多 100 个
    while #self.conversations > 100 do
        table.remove(self.conversations, 1)
    end
    table.insert(self.conversations, conv)
    self.selected_conversation_id = conv.id
end

function Model:get_by_id(id)
    for _, conv in ipairs(self.conversations) do
        if conv.id == id then return conv end
    end
end

function Model:delete_conversation(id)
    for i = #self.conversations, 1, -1 do
        if self.conversations[i].id == id then
            table.remove(self.conversations, i)
        end
    end
end

function Model:delete_all_conversations()
    for i = #self.conversations, 1, -1 do
        if not self.conversations[i].is_favorited then
            table.remove(self.conversations, i)
        end
    end
    self.selected_conversation_id = nil
end
```

## 八、View (view/init.lua)

### 8.1 设计原则

- **3 个稳定 buffer**：创建一次，永不销毁
  - `messages_buf`: markdown ft, `modifiable=false`（渲染时临时开）
  - `input_buf`: `modifiable=true`, buffer-local `<CR>` keymap
  - `reference_buf`: 显示选中文件/选区
- **window 可销毁**：show/hide 只操作 window，不动 buffer
- **会话切换**：全量重绘 messages_buf
- **流式更新**：首帧记录锚点，后续 `nvim_buf_set_text` 替换锚点到末尾

### 8.2 核心渲染逻辑

```lua
function View:update(state)
    local conv_id = state.selected_conversation_id
    if not conv_id then return end

    local conv = state.conversations[conv_id]
    if not conv then return end

    if self.current_conv_id ~= conv_id then
        -- 切换会话: 全量重绘
        self:_clear_buffer()
        self:_render_messages(conv)
        self.current_conv_id = conv_id
        self.last_msg_count = #conv.content.messages
        self.is_streaming = false
        return
    end

    local st = conv.content.state
    if st.type == 'botAnswerStreaming' then
        self:_render_streaming(st.partialAnswer)
    else
        -- 非流式: 增量追加新消息
        if self.last_msg_count < #conv.content.messages then
            for i = self.last_msg_count + 1, #conv.content.messages do
                self:_append_message(conv.content.messages[i])
            end
            self.last_msg_count = #conv.content.messages
        end
        self.is_streaming = false
    end
end

function View:_render_streaming(partial)
    if not self.is_streaming then
        -- 首次进入流式: 追加 bot 标题行, 记录锚点
        self:_append_section('Fitten Code')
        local lines = vim.api.nvim_buf_line_count(self.messages_buf)
        self.streaming_anchor = { lines - 1, 0 }
        self.is_streaming = true
    end
    -- 替换锚点后的所有内容
    vim.api.nvim_buf_set_option(self.messages_buf, 'modifiable', true)
    vim.api.nvim_buf_set_text(
        self.messages_buf,
        self.streaming_anchor[1], self.streaming_anchor[2],
        -1, -1,
        vim.split(partial, '\n', { trimempty = false })
    )
    vim.api.nvim_buf_set_option(self.messages_buf, 'modifiable', false)
end
```

### 8.3 输入处理 (buffer-local keymap)

```lua
function View:_setup_input()
    vim.api.nvim_buf_set_keymap(self.input_buf, 'i', '<CR>', '', {
        callback = function()
            local lines = vim.api.nvim_buf_get_lines(self.input_buf, 0, 1, false)
            local text = vim.trim(lines[1] or '')
            if text == '' then return end

            self:send_msg({
                type = 'send_message',
                data = {
                    id = self.current_conv_id,
                    message = text
                }
            })
            vim.api.nvim_buf_set_lines(self.input_buf, 0, -1, false, {''})
            vim.api.nvim_win_set_cursor(self.input_win, {1, 0})
        end,
    })
end
```

### 8.4 窗口布局

```
┌──────────────────────────┐
│  messages_buf            │  ← 主消息区 (flex 高度)
│  (markdown ft)           │
│                          │
├──────────────────────────┤
│  reference_buf           │  ← 引用信息 (固定 1-3 行)
├──────────────────────────┤
│  input_buf               │  ← 输入区 (固定 3 行)
└──────────────────────────┘
```

使用 `nvim_open_win` split 布局，左侧边栏模式。

## 九、state.lua — 序列化

```lua
function State.get_state_from_model(model)
    local state = {
        selected_conversation_id = model.selected_conversation_id,
        conversations = {},
    }
    for _, conv in ipairs(model.conversations) do
        state.conversations[conv.id] = {
            id = conv.id,
            header = {
                title = conv:get_title(),
                is_title_message = conv:is_title_message(),
                codicon = conv:get_codicon(),
            },
            content = {
                type = 'messageExchange',
                messages = conv.messages,
                state = conv.state,
                error = conv.error,
            },
            timestamp = conv.creation_timestamp,
            is_favorited = conv.is_favorited,
            mode = conv.mode,
        }
    end
    return state
end
```

## 十、入口 (chat/init.lua)

```lua
-- chat/init.lua
local Controller = require('fittencode.chat.controller')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local View = require('fittencode.chat.view')
local Config = require('fittencode.config')

local controller

local function init()
    local conv_type_provider = ConversationTypesProvider.new()
    local view = View.new()
    controller = Controller.new({
        view = view,
        model = Model.new(),
        conversation_types_provider = conv_type_provider,
        basic_chat_template_id = 'chat',
    })

    -- View → Controller 绑定
    view.send_msg = function(msg)
        controller:receive_msg(msg)
    end

    -- 异步加载模板
    conv_type_provider:async_load_conversation_types()

    -- 注册键位
    for action, cfg in pairs(Config.keymaps.chat) do
        if cfg and cfg ~= '' then
            vim.keymap.set({'n', 'x'}, cfg, function()
                controller:from_builtin_template(action)
            end, { noremap = true, silent = true })
        end
    end
end

return {
    init = init,
    get_controller = function() return controller end,
}
```

## 十一、依赖关系

新代码库已有，无需外部依赖：

| 模块 | 用途 |
|---|---|
| `fittencode.client` | `make_request_auth`, `remove_special_token`, `get_api_key_manager` |
| `fittencode.client.protocol` | `Methods.chat_auth`, `Methods.rag_chat` |
| `fittencode.http` | fetch/stream/abort (curl 底层) |
| `fittencode.opl` | 模板求值 `OPL.run(env, template)` |
| `fittencode.fn.promise` | Promise (forward/catch/finally/wait) |
| `fittencode.fn.core` | `generate_short_id`, `startswith`, `schedule_call` |
| `fittencode.fn.progress_indicator` | ProgressIndicator (spinner) |
| `fittencode.log` | 日志 + 通知 |
| `fittencode.i18n` | 国际化 `i18n.tr()` |
| `fittencode.config` | 配置读取 |
