---@class FittenCode.Error
---@field type string @错误类型标识
---@field message string|string[] @错误描述
---@field cause? FittenCode.Error @错误原因
---@field metadata? table<string, any> @附加信息

---@class FittenCode.HTTP.RequestOptions
---@field method? string @HTTP 方法 (默认: 'GET')
---@field headers? table<string, string> @请求头
---@field body? string @请求体内容
---@field timeout? number @超时时间（毫秒）
---@field follow_redirects? boolean @是否跟随重定向 (默认: true)

---@class FittenCode.HTTP.Request
---@field stream FittenCode.HTTP.Request.Stream @响应流对象
---@field abort fun(self: FittenCode.HTTP.Request) @中止请求方法
---@field async fun(self: FittenCode.HTTP.Request): FittenCode.Promise @启动请求并返回关联的 Promise 对象
---@field _async any

---@class FittenCode.HTTP.Request.Stream
---@field on fun(self: FittenCode.HTTP.Request.Stream, event: FittenCode.HTTP.Request.Stream.Event, callback: function): FittenCode.HTTP.Request.Stream
---@field _emit fun(self: FittenCode.HTTP.Request.Stream, event: FittenCode.HTTP.Request.Stream.Event, ...: any)
---@field _buffer table<string> @响应内容缓冲区
---@field _status? integer @HTTP 状态码
---@field _headers? table<string, string> @响应头
---@field _callbacks table<FittenCode.HTTP.Request.Stream.Event, function> @事件回调表

---@alias FittenCode.HTTP.Request.Stream.Event
---| '"headers"'  # 收到响应头时触发
---| '"data"'     # 收到响应数据块时触发
---| '"end"'      # 响应完成时触发
---| '"error"'    # 发生错误时触发
---| '"abort"'    # 请求被中止时触发

---@class FittenCode.HTTP.Request.Stream.HeadersEvent
---@field status integer @HTTP 状态码
---@field headers table<string, string> @响应头表

---@class FittenCode.HTTP.Request.Stream.EndEvent
---@field status integer|integer[] @HTTP 状态码
---@field headers table<string, string> @响应头表
---@field ok boolean @是否成功状态码 (200-299)
---@field timing? fun(): FittenCode.HTTP.Timing @请求计时信息
---@field text fun(): string @获取响应文本方法
---@field json fun(): any? @解析响应JSON方法

---@class FittenCode.HTTP.Request.Stream.ErrorEvent.Metadata
---@field code? integer @CURL 错误码
---@field signal? integer @系统信号码
---@field timing? fun(): FittenCode.HTTP.Timing @请求计时信息
---@field readable_code string @可读错误类型

---@class FittenCode.HTTP.Request.Stream.ErrorEvent : FittenCode.Error
---@field metadata? FittenCode.HTTP.Request.Stream.ErrorEvent.Metadata @附加信息

---@class FittenCode.HTTP.Timing
---@field dns number      @DNS 查询耗时（毫秒）
---@field tcp number      @TCP 连接耗时（毫秒）
---@field ssl number      @SSL 握手耗时（毫秒）
---@field ttfb number     @首字节时间（毫秒）
---@field total number    @总耗时（毫秒）

---@class FittenCode.Inline.Prompt
---@field inputs string
---@field meta_datas FittenCode.Inline.Prompt.MetaDatas

-- 元信息
---@class FittenCode.Inline.Prompt.MetaDatas
---@field plen number 对比结果的相似前缀的长度 UTF-16
---@field slen number 对比结果的相似后缀的长度 UTF-16
---@field bplen number 前缀文本的 UTF-8 字节长度
---@field bslen number 后缀文本的 UTF-8 字节长度
---@field pmd5 string Prev MD5
---@field nmd5 string New MD5 (Prefix + Suffix)
---@field diff string 差异文本，如果是首次则是 Prefix + Suffix，后续则是对比结果
---@field filename string 文件名
---@field cpos number Prefix 的 UTF-16 长度
---@field bcpos number Prefix 的 UTF-8 字节长度
---@field pc_available boolean Project Completion 是否可用
---@field pc_prompt string Project Completion Prompt
---@field pc_prompt_type string Project Completion Prompt 类型
---@field edit_mode boolean|string 是否处于 Edit Completion 模式
---@field edit_mode_history string
---@field edit_mode_trigger_type string
