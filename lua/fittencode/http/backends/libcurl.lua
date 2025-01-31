local ffi = require('ffi')
local M = {}

ffi.cdef [[
typedef void CURL;
typedef struct curl_slist curl_slist;
typedef enum {
  CURLE_OK = 0,
  CURLOPT_URL = 10002,
  CURLOPT_WRITEFUNCTION = 20011,
  CURLOPT_WRITEDATA = 10001,
  CURLOPT_HEADERFUNCTION = 20079,
  CURLOPT_HEADERDATA = 10029,
  CURLOPT_NOPROGRESS = 43,
  CURLOPT_FOLLOWLOCATION = 52,
  CURLOPT_TIMEOUT_MS = 155,
  CURLOPT_MAXREDIRS = 68,
  CURLOPT_USERAGENT = 10018,
  CURLOPT_SSL_VERIFYPEER = 64,
  CURLOPT_CUSTOMREQUEST = 10036,
  CURLOPT_POSTFIELDS = 10015,
  CURLOPT_POSTFIELDSIZE = 60,
  CURLINFO_RESPONSE_CODE = 2097154,
  CURLINFO_NAMELOOKUP_TIME = 3145733,
  CURLINFO_CONNECT_TIME = 3145734,
  CURLINFO_APPCONNECT_TIME = 3145765,
  CURLINFO_PRETRANSFER_TIME = 3145735,
  CURLINFO_STARTTRANSFER_TIME = 3145736,
  CURLINFO_TOTAL_TIME = 3145737,
  CURLINFO_SIZE_DOWNLOAD = 3145743
} CURLoption;

CURL *curl_easy_init();
void curl_easy_cleanup(CURL *curl);
curl_slist *curl_slist_append(curl_slist *list, const char *string);
void curl_slist_free_all(curl_slist *list);
CURLcode curl_easy_setopt(CURL *curl, CURLoption option, ...);
CURLcode curl_easy_perform(CURL *curl);
const char *curl_easy_strerror(CURLcode code);
CURLcode curl_easy_getinfo(CURL *curl, CURLoption option, ...);
]]

local curl = ffi.load('curl')

local function create_stream()
    return {
        _buffer = {},
        _headers = nil,
        _callbacks = {},
        on = function(self, event, cb)
            self._callbacks[event] = cb
            return self
        end,
        _emit = function(self, event, ...)
            local cb = self._callbacks[event]
            if cb then cb(...) end
        end
    }
end

local function parse_headers(raw_headers)
    local headers = {}
    for line in vim.gsplit(raw_headers, '\r\n') do
        local name, value = line:match('^([^%s:]+):%s*(.*)$')
        if name then
            headers[name:lower()] = value
        elseif line:find('^HTTP/') then
            headers.status = tonumber(line:match(' (%d+) '))
        end
    end
    return headers
end

function M.fetch(url, opts)
    opts = opts or {}
    local handle = curl.curl_easy_init()
    if handle == nil then return nil, 'Failed to initialize CURL' end

    local stream = create_stream()
    local req_handle = { aborted = false }
    local headers_list = ffi.new('curl_slist*[1]')

    -- 构建请求参数
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_URL, url)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_FOLLOWLOCATION, 1)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_MAXREDIRS, opts.max_redirects or 5)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_TIMEOUT_MS, opts.timeout or 30000)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_SSL_VERIFYPEER, opts.validate_ssl ~= false and 1 or 0)

    -- 设置请求方法
    if opts.method then
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_CUSTOMREQUEST, opts.method)
    end

    -- 设置请求头
    if opts.headers then
        for k, v in pairs(opts.headers) do
            headers_list[0] = curl.curl_slist_append(headers_list[0], string.format('%s: %s', k, v))
        end
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_HTTPHEADER, headers_list[0])
    end

    -- 请求体处理
    local body = opts.body
    if body then
        if type(body) == 'table' then
            body = vim.json.encode(body)
        end
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_POSTFIELDS, body)
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_POSTFIELDSIZE, #body)
    end

    -- 响应处理回调
    local header_data = {}
    local write_cb = ffi.cast('curl_write_callback', function(ptr, size, nmemb, userdata)
        local chunk = ffi.string(ptr, size * nmemb)
        table.insert(stream._buffer, chunk)
        stream:_emit('data', chunk)
        return size * nmemb
    end)

    local header_cb = ffi.cast('curl_write_callback', function(ptr, size, nmemb, userdata)
        local header = ffi.string(ptr, size * nmemb)
        table.insert(header_data, header)
        return size * nmemb
    end)

    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_WRITEFUNCTION, write_cb)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_HEADERFUNCTION, header_cb)

    -- 异步执行
    local timer = vim.uv.new_timer()
    local done = false

    vim.uv.new_work(function()
        local res = curl.curl_easy_perform(handle)
        return res
    end, function(res)
        if not done then
            done = true
            timer:stop()
            timer:close()

            -- 解析计时信息
            local timing = {}
            local get_info = function(opt)
                local val = ffi.new('double[1]')
                curl.curl_easy_getinfo(handle, opt, val)
                return tonumber(val[0]) * 1000 -- 转换为毫秒
            end

            timing.dns = get_info(ffi.C.CURLINFO_NAMELOOKUP_TIME)
            timing.tcp = get_info(ffi.C.CURLINFO_CONNECT_TIME) - timing.dns
            timing.ssl = get_info(ffi.C.CURLINFO_APPCONNECT_TIME) - timing.tcp - timing.dns
            timing.pretransfer = get_info(ffi.C.CURLINFO_PRETRANSFER_TIME)
            timing.ttfb = get_info(ffi.C.CURLINFO_STARTTRANSFER_TIME) - timing.pretransfer
            timing.total = get_info(ffi.C.CURLINFO_TOTAL_TIME)

            -- 解析响应头
            local headers = parse_headers(table.concat(header_data))
            local status_code = headers.status or 500

            -- 清理资源
            if headers_list[0] then
                curl.curl_slist_free_all(headers_list[0])
            end
            curl.curl_easy_cleanup(handle)

            -- 触发回调
            if res == ffi.C.CURLE_OK then
                stream:_emit('headers', headers)
                stream:_emit('end', {
                    status = status_code,
                    headers = headers,
                    text = table.concat(stream._buffer),
                    timing = timing,
                    json = function()
                        return vim.json.decode(table.concat(stream._buffer))
                    end
                })
            else
                stream:_emit('error', {
                    code = res,
                    message = ffi.string(curl.curl_easy_strerror(res))
                })
            end
        end
    end)()

    -- 超时处理
    timer:start(opts.timeout or 30000, 0, function()
        if not done then
            done = true
            curl.curl_easy_cleanup(handle)
            stream:_emit('error', {
                code = 28,
                message = 'Operation timed out'
            })
        end
    end)

    -- 中止控制
    req_handle.abort = function()
        if not done then
            done = true
            curl.curl_easy_cleanup(handle)
            timer:stop()
            timer:close()
            stream:_emit('abort')
        end
    end

    return {
        stream = stream,
        abort = req_handle.abort,
        promise = function()
            return require('promise').new(function(resolve, reject)
                stream:on('end', resolve)
                stream:on('error', reject)
                stream:on('abort', function()
                    reject('Request aborted')
                end)
            end)
        end
    }
end

return M
