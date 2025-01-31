-- lua/http/backends/libcurl.lua
local ffi = require("ffi")
local uv = vim.uv or vim.loop
local M = {}

ffi.cdef[[
typedef void CURL;
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
  CURLOPT_SSL_VERIFYPEER = 64
} CURLoption;

CURL *curl_easy_init();
void curl_easy_cleanup(CURL *curl);
CURLcode curl_easy_setopt(CURL *curl, CURLoption option, ...);
CURLcode curl_easy_perform(CURL *curl);
const char *curl_easy_strerror(CURLcode code);
]]

local curl = ffi.load("curl")

local function create_handle(spec, config)
    local handle = curl.curl_easy_init()
    if handle == nil then return nil, "failed to init curl handle" end

    -- 基本参数设置
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_URL, spec.url)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_FOLLOWLOCATION, spec.follow_redirects and 1 or 0)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_MAXREDIRS, config.max_redirects)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_USERAGENT, config.user_agent)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_TIMEOUT_MS, spec.timeout or config.timeout)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_SSL_VERIFYPEER, spec.validate_ssl and 1 or 0)

    return handle
end

function M.request(spec, callback)
    local config = require("http").config
    local handle, err = create_handle(spec, config)
    if not handle then return nil, err end

    local response = {
        headers = {},
        body = {},
        status = nil
    }

    -- 响应头回调
    local header_cb = ffi.cast("curl_write_callback", function(ptr, size, nmemb, userdata)
        local header = ffi.string(ptr, size * nmemb)
        local name, value = header:match("^([^%s:]+):%s*(.*)\r?$")
        if name then
            response.headers[name:lower()] = value
        elseif header:find("^HTTP/") then
            response.status = tonumber(header:match(" (%d+) "))
        end
        return size * nmemb
    end)

    -- 响应体回调
    local write_cb = ffi.cast("curl_write_callback", function(ptr, size, nmemb, userdata)
        table.insert(response.body, ffi.string(ptr, size * nmemb))
        return size * nmemb
    end)

    -- 设置回调
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_HEADERFUNCTION, header_cb)
    curl.curl_easy_setopt(handle, ffi.C.CURLOPT_WRITEFUNCTION, write_cb)

    -- 异步执行
    local timer = uv.new_timer()
    local done = false

    uv.new_work(function()
        local code = curl.curl_easy_perform(handle)
        return code
    end, function(code)
        if not done then
            done = true
            timer:stop()
            timer:close()
            
            local err = code ~= ffi.C.CURLE_OK and ffi.string(curl.curl_easy_strerror(code)) or nil
            response.body = table.concat(response.body)
            
            if callback then
                callback(err and nil or response, err)
            end
            
            curl.curl_easy_cleanup(handle)
        end
    end)()

    -- 超时处理
    timer:start(config.timeout, 0, function()
        if not done then
            done = true
            curl.curl_easy_cleanup(handle)
            if callback then
                callback(nil, "timeout after "..config.timeout.."ms")
            end
        end
    end)

    return {
        abort = function()
            if not done then
                done = true
                curl.curl_easy_cleanup(handle)
                timer:stop()
                timer:close()
                if callback then
                    callback(nil, "request aborted")
                end
            end
        end
    }
end

return M