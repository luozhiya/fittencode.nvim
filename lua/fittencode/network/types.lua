---@class FittenCode.HTTP.Request.Backend
---@field fetch fun(url: string, options?: FittenCode.HTTP.Request): FittenCode.HTTP.Response

---@class FittenCode.HTTP.Request
---@field method? string @HTTP 方法 (默认: 'GET')
---@field headers? table<string, string> @请求头
---@field body? string @请求体内容
---@field body_file? string @请求体文件路径
---@field timeout? number @超时时间（毫秒）
---@field follow_redirects? boolean @是否跟随重定向 (默认: true)

---@class FittenCode.HTTP.Response
---@field stream FittenCode.HTTP.Request.Stream @响应流对象
---@field abort fun() @中止请求方法
---@field run fun() @启动请求方法
---@field promise fun(): FittenCode.Concurrency.Promise @启动请求并返回关联的 Promise 对象

---@class FittenCode.HTTP.Request.Stream
---@field on fun(self: FittenCode.HTTP.Request.Stream, event: FittenCode.HTTP.Request.Stream.Event, callback: function): FittenCode.HTTP.Request.Stream
---@field _emit fun(self: FittenCode.HTTP.Request.Stream, event: FittenCode.HTTP.Request.Stream.Event, ...: any)
---@field _buffer string @响应内容缓冲区
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
---@field status integer @HTTP 状态码
---@field headers table<string, string> @响应头表
---@field ok boolean @是否成功状态码 (200-299)
---@field timing? fun(): FittenCode.Network.Timing @请求计时信息
---@field text fun(): string @获取响应文本方法
---@field json fun(): any? @解析响应JSON方法

---@class FittenCode.HTTP.Request.Stream.ErrorEvent
---@field type string @错误类型标识
---@field code? integer @CURL 错误码
---@field signal? integer @系统信号码
---@field message string @错误描述
---@field timing? fun(): FittenCode.Network.Timing @请求计时信息
---@field readable_type string @可读错误类型

---@class FittenCode.Network.Timing
---@field dns number      @DNS 查询耗时（毫秒）
---@field tcp number      @TCP 连接耗时（毫秒）
---@field ssl number      @SSL 握手耗时（毫秒）
---@field ttfb number     @首字节时间（毫秒）
---@field total number    @总耗时（毫秒）

-- 错误类型定义
---@class FittenCode.Network.Error
---@field CURL_ERROR_CODES table<integer, string> @CURL 错误码映射表

---@alias FittenCode.Network.Error.Type
---| '"CURL_ERROR"'    # CURL 底层错误
---| '"HTTP_ERROR"'    # HTTP 4xx/5xx 错误
---| '"USER_ABORT"'    # 用户主动取消
---| '"PARSE_ERROR"'   # 数据解析错误
---| '"NETWORK_ERROR"' # 网络连接错误
