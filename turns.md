# Chat 实现全过程记录

> 每轮迭代的问题、决策与修复。

---

## Turn 1 — 架构设计

**输入**: 基于 VSCode extension.js 反混淆分析和旧 neovim 代码，设计新 chat 架构。

**决策**:
- 两层消息模式（与 JS 对齐）：View → Controller（用户动作 msg），Controller → View（全量 state）
- Observer 侧通道（`on/emit`）独立于核心数据流
- 不用 `definitions.lua`，字符串字面量代替常量
- `ctrl_observer.lua` 保留但精简为 `StatusObserver` + `ProgressIndicatorObserver`
- View: 3-window 布局 (msg / ref / input)
- pi 归 `ProgressIndicatorObserver`，不进 View

**创建文件**: 12 个 lua 文件 + 修改 `commands.lua`

---

## Turn 2 — View 单 buffer 误解

**输入**: "view结构不对,输入框和输出框是同一个且是中间那个"

**错误理解**（我）: 以为是需求——把输入和输出合并为同一 buffer 置于中间。

**纠正**（用户）: "这个并不是要实现的目标,而是你出现的问题!" —— 这是我引入的 bug，不是需求。

**恢复**: 回到 3-window 分离 layout。

---

## Turn 3 — Enter 键无反应 (冒号 bug)

**现象**: 输入文字按 Enter 无响应。日志显示 `[Chat.View] Sending message` 但无 `[Chat.Controller] receive_msg`。

**根因**: `self:send_msg(...)` 冒号调用将 View 自身作为 `self` 隐式传参，导致 `receive_msg` 收到的 `msg` 是 View 对象（`msg.type = nil`），直接 return。

**修复**: `self:send_msg(...)` → `self.send_msg(...)`（点号调用）
同时修复 `conversation.lua` 中 `self:update_view()` → `self.update_view()`（6 处）

---

## Turn 4 — Window 布局错误

**现象**: 3 窗口分层错乱。"输入框和输出框是同一个且是中间那个"

**根因**: `msg_win` 用了 `vertical = true` + `split = 'left'` + `height = editor_height`，导致全高占满。`ref_win`/`inp_win` 使用 `vertical = true` + `split = 'below'` 冲突。

**修复**: `split = 'below'` 去掉 `vertical = true` 和 `width`，继承父窗口。创建顺序：msg(全高) → ref(below, 5) → inp(below, 3)，全部 `enter=true`。

---

## Turn 5 — 回复重复 + 流式洪水

**问题 A - 回复重复**:
用户在消息区看到 bot 回复出现两次。

**根因**: 流式阶段 `ng_bot_message` 把 partial 内容渲染到 buffer。流式结束后 `add_bot_message` 把相同内容推入 `messages[]` 并触发 `update_view`，view 再次 `_append_message` 追加一次 → 重复。

**修复**: 新增 `was_streaming` 标记。流式结束时 view 检测 `was_streaming == true` 且 `state.type != 'botAnswerStreaming'`，只同步 `last_msg_count`，不做 buffer 操作。

**问题 B - 流式洪水**:
每个 NDJSON chunk 触发 `update_partial_bot_message` → `update_view` → buffer 写操作，每秒约 40 次。

**修复**: `_render_streaming` 加 `streaming_pending` 门控 + `vim.schedule`，已排队的更新未执行完时跳过新请求。实际降到每秒约 1 次。

---

## Turn 6 — 流式结束后替换逻辑优化

**问题**: `was_streaming` 过渡分支用 `nvim_buf_set_text` 从 anchor 替换到末尾。完成时内容相同是无感替换，但 `stop_waiting` 时内容不同也全部替换。

**修复**: 取消 `nvim_buf_set_text` 替换逻辑，`was_streaming` 分支恢复为纯状态同步（`last_msg_count = msg_count`）。

`stop_waiting` 不再向 `messages[]` 推取消消息，只改 `state`。view 自行保留流式残留。

---

## Turn 7 — Chat 输出时禁止用户输入

**需求**: 流式期间应阻止用户在 input 中输入。

**方案 A（放弃）**: `_set_input_enabled(false)` → `modifiable=false` → 阻塞 insert 模式。

**Bug**: Enter 的 `<CR>` keymap 仍在 `modifiable=false` 的 buffer 上触发，回调内 `nvim_buf_set_lines` 写不可修改 buffer 报错 `E5108`。

**回退条件**: 回调内先清空 input 再 `send_msg`，但因 `_set_input_enabled(false)` 在 `send_msg` → `update_view` 链中被同步调用，时序错误。

**方案 B（最终）**: **pending 队列**。

---

## Turn 8 — Pending 队列

**设计**:
- input buffer 始终保持 `modifiable=true`
- 新增 `current_state_type` 追踪当前状态
- Enter 时检查状态：
  - `userCanReply` → 直接发送
  - `waitingForBotAnswer` / `botAnswerStreaming` → 存 `pending_text`
- `update()` 末尾 `_try_flush_pending()` 检测 state 恢复为 `userCanReply` 时自动发送

**Pending 浮动窗口**: 在 `inp_win` 上方显示，`style='minimal'`，`focusable=false`。用户可连续 Enter 追加多行。

**删掉**: `_set_input_enabled` 及其调用，`modifiable` 切换逻辑。

---

## Turn 9 — Pending 合并 + 底色

**需求 A**: pending 多条用 `\n` 连接发送。

**修复**: `_setup_input` 的 `<CR>` 回调中 `pending_text` 存在时追加 `'\n' .. text`。

**需求 B**: pending 窗口加底色区分。

**修复**: `vim.api.nvim_set_hl(0, 'FittenCodePending', { bg = '#2a2a3a' })`，窗口 `winhl='Normal:FittenCodePending'`。

---

## Turn 10 — Pending 向下增长覆盖 input

**问题**: `nvim_win_set_config` 更新已有 pending 窗口时只设 `height` 不设 `row`，导致多行向下增长覆盖 input 区域。

**方案 A（放弃）**: `nvim_win_set_config(pending_win, { row = -#lines, height = #lines })` — `relative='win'` 的 `row` 在 `set_config` 中不可靠。

**方案 B（最终）**: 每次 `_show_pending` 先 `_hide_pending` 关闭旧窗口，完全重建。保证 `row = -#lines` 始终精确。

**附带 fix**: `feedkeys('i')` 多余且有害（已处于 insert 模式时会插入字面量 `i`），删除。

---

## Turn 11 — 去掉 reference 固定窗口

**需求**: reference 窗口改为浮动，仅在有引用数据时出现。

**改动**:
- 删除 `ref_win` 从 `show()` / `_destroy_windows()`
- 新增 `_update_ref(ref)` / `_show_ref(ref)` / `_hide_ref()`
- `view/state.lua` 新增从 `conv.context` 提取 reference 的逻辑
- 浮动窗口位于编辑器右上角，`style='minimal'`，`zindex=10`

---

## Turn 12 — Commit

提交 `1cb0feb9`: 13 files, 1701 lines。

---

## 文件清单

```
lua/fittencode/chat/
├── init.lua                          (71)  入口: 组装 + 命令/键位注册
├── controller.lua                    (259) receive_msg + update_view + on/emit
├── ctrl_observer.lua                 (75)  StatusObserver + ProgressIndicatorObserver
├── conversation.lua                  (247) 核心: 状态机 + NDJSON 流 + abort
├── conversation_type.lua             (46)  工厂: Template → Conversation
├── conversation_types_provider.lua   (115) 模板加载 (builtin/extension/workspace)
├── model.lua                         (89)  会话列表 (max 100)
├── builtin_templates.lua             (46)  模板清单 + 分类映射
├── template_resolver.lua             (141) .rdt.md treesitter 解析
├── _types.lua                        (128) LuaLS 类型标注
└── view/
    ├── init.lua                      (310) UI: 2-window + pending 浮动 + 引用浮动
    └── state.lua                     (50)  Model → ViewState 序列化
```

## 架构图

```
┌──────────────────────────────────────────────────────────┐
│  View (view/init.lua)                                    │
│  ┌── update(state) ←── Controller:update_view()          │
│  └── send_msg(msg) ──→ Controller:receive_msg(msg)       │
│  2-window: msg_win (messages) + inp_win (input)          │
│  Floating: ref_win (右上) + pending_win (input 上方)      │
└──────────────────────────┬───────────────────────────────┘
                           │  state          │  msg
┌──────────────────────────┴─────────────────┴─────────────┐
│  Controller (controller.lua)                              │
│  ┌── receive_msg(msg): 路由到 Conversation / Model        │
│  ├── update_view(): 序列化 Model → state → View:update    │
│  └── on/emit: observer 侧通道 ────────┐                   │
└───────────────────────────────────────┼───────────────────┘
                           │  update_view() callback
┌──────────────────────────┴────────────────────────────────┐
│  Conversation (conversation.lua)                           │
│  State machine:                                            │
│    userCanReply → answer() → waitingForBotAnswer           │
│    → stream:on('data') → botAnswerStreaming                │
│    → async():then() → add_bot_message → userCanReply       │
│  Abort: stop_waiting() → request_handle:abort()            │
│  Pending: view blocks, queues in pending_text              │
└───────────────────────────────────────────────────────────┘

Observer 侧通道:
  Controller:on/emit → StatusObserver.get_snapshot()
                     → ProgressIndicatorObserver.pi:start/stop
```

## 待做

- `add_selection_context_to_input` 选区添加上下文（keymap 已注册，回调空实现）
- inline 补全过滤 chat buffer（需改 `inline/controller.lua`）
- 会话持久化（当前纯内存）
- `@workspace` RAG 支持
- Agent pipeline（ProjectAgent/ReferenceAgent 等，当前只做简单字符串拼接）
- 模板语言后缀 fallback 从 `-en` 扩展到其他语言
