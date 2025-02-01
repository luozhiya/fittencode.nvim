local ffi = require('ffi')
local Promise = require('fittencode.concurrency.promise')

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
  CURLOPT_TCP_FASTOPEN = 244,
  CURLOPT_ACCEPT_ENCODING = 10102,
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

local CURL_ERROR_CODES = {
    [6]  = 'DNS_RESOLUTION_FAILED',
    [7]  = 'CONNECTION_REFUSED',
    [28] = 'TIMEOUT_REACHED',
    [35] = 'SSL_HANDSHAKE_ERROR',
    [47] = 'TOO_MANY_REDIRECTS'
}

local function create_stream()
    return {
        _buffer = '',
        _headers = nil,
        _status = nil,
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

local function parse_headers(header_lines)
    local headers = {}
    for _, line in ipairs(header_lines) do
        if line:find('^HTTP/') then
            headers.status = tonumber(line:match(' (%d+) '))
        else
            local name, val = line:match('^([^%s:]+):%s*(.*)$')
            if name then headers[name:lower()] = val end
        end
    end
    return headers
end

function M.fetch(url, opts)
    opts = opts or {}
    local handle = curl.curl_easy_init()
    if not handle then return nil, 'Failed to initialize CURL' end

    local stream = create_stream()
    local req_handle = { aborted = false }
    local headers_list = ffi.new('curl_slist*[1]')
    local header_lines = {}
    local body_buffer = {}
    local headers_processed = false

    -- 基础配置
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_URL, url)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_FOLLOWLOCATION, 1)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_MAXREDIRS, opts.max_redirects or 5)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_TIMEOUT_MS, opts.timeout or 30000)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_SSL_VERIFYPEER, opts.validate_ssl ~= false and 1 or 0)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_TCP_FASTOPEN, 1)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_ACCEPT_ENCODING, '')
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_NOPROGRESS, 1)

    -- 请求方法
    local method = opts.method or 'GET'
    if method ~= 'GET' then
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_CUSTOMREQUEST, method)
    end

    -- 请求头
    if opts.headers then
        for k, v in pairs(opts.headers) do
            headers_list[0] = curl.curl_slist_append(headers_list[0], string.format('%s: %s', k, v))
        end
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_HTTPHEADER, headers_list[0])
    end

    -- 请求体
    if opts.body then
        local body = type(opts.body) == 'table' and vim.json.encode(opts.body) or opts.body
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_POSTFIELDS, body)
        curl.curl_easy_setopt(handle, ffi.C.CURLOPT_POSTFIELDSIZE, #body)
    end

    -- 响应处理回调
    local header_cb = ffi.cast('curl_write_callback', function(ptr, size, nmemb)
        local line = ffi.string(ptr, size * nmemb)
        if line == '\r\n' or line == '\n' then
            local headers = parse_headers(header_lines)
            stream:_emit('headers', { status = headers.status, headers = headers })
            stream._status = headers.status
            stream._headers = headers
            headers_processed = true
            -- 处理缓存的body数据
            if #body_buffer > 0 then
                local data = table.concat(body_buffer)
                stream._buffer = stream._buffer .. data
                stream:_emit('data', data)
                body_buffer = {}
            end
            header_lines = {}
        else
            table.insert(header_lines, line)
        end
        return size * nmemb
    end)

    local write_cb = ffi.cast('curl_write_callback', function(ptr, size, nmemb)
        local data = ffi.string(ptr, size * nmemb)
        if headers_processed then
            stream._buffer = stream._buffer .. data
            stream:_emit('data', data)
        else
            table.insert(body_buffer, data)
        end
        return size * nmemb
    end)

    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_HEADERFUNCTION, header_cb)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_WRITEFUNCTION, write_cb)

    -- 异步执行
    local timer = vim.uv.new_timer()
    local done = false

    vim.uv.new_work(function()
        return curl.curl_easy_perform(handle)
    end, function(res)
        if done then return end
        done = true
        timer:stop()
        timer:close()

        -- 解析计时信息
        local timing = {}
        local get_info = function(opt)
            local val = ffi.new('double[1]')
            curl.curl_easy_getinfo(handle, opt, val)
            return tonumber(val[0]) * 1000
        end

        timing = {
            dns = get_info(ffi.C.CURLINFO_NAMELOOKUP_TIME),
            tcp = get_info(ffi.C.CURLINFO_CONNECT_TIME) - get_info(ffi.C.CURLINFO_NAMELOOKUP_TIME),
            ssl = get_info(ffi.C.CURLINFO_APPCONNECT_TIME) - get_info(ffi.C.CURLINFO_CONNECT_TIME),
            ttfb = get_info(ffi.C.CURLINFO_STARTTRANSFER_TIME) - get_info(ffi.C.CURLINFO_PRETRANSFER_TIME),
            total = get_info(ffi.C.CURLINFO_TOTAL_TIME),
            size_download = get_info(ffi.C.CURLINFO_SIZE_DOWNLOAD)
        }

        -- 清理资源
        if headers_list[0] then curl.curl_slist_free_all(headers_list[0]) end
        curl.curl_easy_cleanup(handle)
        ---@diagnostic disable-next-line: undefined-field
        header_cb:free()
        ---@diagnostic disable-next-line: undefined-field
        write_cb:free()

        -- 处理结果
        if res == ffi.C.CURLE_OK then
            local ok = stream._status and stream._status >= 200 and stream._status < 300
            stream:_emit('end', {
                status = stream._status,
                headers = stream._headers,
                ok = ok,
                timing = timing,
                text = function() return stream._buffer end,
                json = function() return vim.json.decode(stream._buffer) end
            })
        else
            stream:_emit('error', {
                type = 'CURL_ERROR',
                code = res,
                message = ffi.string(curl.curl_easy_strerror(res)),
                readable_type = CURL_ERROR_CODES[res] or 'UNKNOWN_ERROR',
                timing = timing
            })
        end
    end)()

    -- 超时处理
    timer:start(opts.timeout or 30000, 0, function()
        if not done then
            req_handle.abort()
            stream:_emit('error', {
                type = 'CURL_ERROR',
                code = 28,
                message = 'Operation timed out',
                readable_type = 'TIMEOUT_REACHED',
                timing = {}
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
            return Promise:new(function(resolve, reject)
                stream:on('end', function(response)
                    if response.ok then
                        resolve(response)
                    else
                        reject({
                            type = 'HTTP_ERROR',
                            status = response.status,
                            response = response
                        })
                    end
                end)
                stream:on('error', reject)
                stream:on('abort', function()
                    reject({ type = 'USER_ABORT' })
                end)
            end)
        end
    }
end

return M
