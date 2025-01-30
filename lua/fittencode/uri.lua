-- A universal resource identifier representing either a file on disk or another resource.
--
-- src\vs\monaco.d.ts
-- src\vs\base\common\uri.ts
--
-- Uniform Resource Identifier (Uri) http://tools.ietf.org/html/rfc3986.
-- This class is a simple parser which creates the basic component parts
-- (http://tools.ietf.org/html/rfc3986#section-3) with minimal validation
-- and encoding.
-- ```txt
--       foo://example.com:8042/over/there?name=ferret#nose
--       \_/   \______________/\_________/ \_________/ \__/
--        |           |            |            |        |
--     scheme     authority       path        query   fragment
--        |   _____________________|__
--       / \ /                        \
--       urn:example:animal:ferret:nose
-- ```

local M = {}

-- RFC 3986 保留字符集
local reserved_chars = {
    gen_delims = { ':', '/', '?', '#', '[', ']', '@' },
    sub_delims = { '!', '$', '&', "'", '(', ')', '*', '+', ',', ';', '=' }
}

local function uri_encode(str, encode_reserved)
    return str:gsub(
        '([^%w%-%.%_%~])',
        function(c)
            if encode_reserved then
                return string.format('%%%02X', string.byte(c))
            else
                -- 检查是否为保留字符
                for _, v in pairs(reserved_chars.gen_delims) do
                    if c == v then return c end
                end
                for _, v in pairs(reserved_chars.sub_delims) do
                    if c == v then return c end
                end
                return string.format('%%%02X', string.byte(c))
            end
        end
    )
end

local function uri_decode(str)
    return str:gsub(
        '%%(%x%x)',
        function(hex)
            local char = string.char(tonumber(hex, 16))
            -- 保留字符解码保护
            for _, v in pairs(reserved_chars.gen_delims) do
                if char == v then return '%%' .. hex end
            end
            for _, v in pairs(reserved_chars.sub_delims) do
                if char == v then return '%%' .. hex end
            end
            return char
        end
    )
end

local URI = {}
URI.__index = URI

function URI:parse(input)
    -- 增强版 RFC 3986 正则表达式
    local pattern = '^([^:/?#]+):(?://([^/?#]*))?([^?#]*)(?:%?([^#]*))?(?:#(.*))?$'
    local scheme, authority, path, query, fragment = input:match(pattern)

    if not scheme then
        error(string.format('Invalid URI format: %q', input))
    end

    self.scheme = scheme:lower()
    self.authority = authority and uri_decode(authority) or ''
    self.path = self:_normalize_path(uri_decode(path or ''))
    self.query = query and uri_decode(query) or ''
    self.fragment = fragment and uri_decode(fragment) or ''

    -- 解析 authority 组件
    self:_parse_authority()
end

function URI:_parse_authority()
    if self.authority == '' then return end

    -- 解析 userinfo@host:port 格式
    local userinfo, hostport = self.authority:match('^(.*)@(.*)$')
    if not userinfo then hostport = self.authority end

    self.host = hostport
    self.port = nil
    self.userinfo = userinfo

    -- 解析 IPv6地址
    if hostport:match('^%[.+%]$') then
        self.host = hostport:match('^%[(.+)%]$')
        local port_part = hostport:match('%]:(%d+)$')
        if port_part then
            self.port = tonumber(port_part)
        end
    else
        -- 普通主机端口解析
        local host, port = hostport:match('^(.-):(%d+)$')
        if host and port then
            self.host = host
            self.port = tonumber(port)
        end
    end
end

function URI:_normalize_path(path)
    -- 路径规范化处理
    if path == '' then return '' end

    -- 处理 Windows 驱动器号
    if path:match('^/[A-Za-z]:') then
        path = path:gsub('/', '', 1)
    end

    -- 拆分路径组件
    local parts = {}
    for part in path:gmatch('[^/]+') do
        if part == '.' then
            -- 忽略当前目录
        elseif part == '..' then
            if #parts > 0 then
                table.remove(parts)
            end
        else
            table.insert(parts, part)
        end
    end

    local normalized = table.concat(parts, '/')
    if path:sub(1, 1) == '/' then
        normalized = '/' .. normalized
    end
    if path:sub(-1, -1) == '/' then
        normalized = normalized .. '/'
    end

    return normalized
end

function URI:to_string(encode_reserved)
    encode_reserved = encode_reserved == nil and true or encode_reserved

    local parts = { self.scheme, ':' }

    if self.authority ~= '' then
        table.insert(parts, '//' .. uri_encode(self.authority, encode_reserved))
    end

    local path = uri_encode(self.path, encode_reserved)
    if self.scheme == 'file' then
        if path == '' then path = '/' end
        -- Windows 路径特殊处理
        if vim.fn.has('win32') == 1 and path:match('^/[A-Za-z]:') then
            path = path:sub(2)
        end
    end
    table.insert(parts, path)

    if self.query ~= '' then
        table.insert(parts, '?' .. uri_encode(self.query, encode_reserved))
    end

    if self.fragment ~= '' then
        table.insert(parts, '#' .. uri_encode(self.fragment, encode_reserved))
    end

    return table.concat(parts, '')
end

function URI:to_filepath()
    if self.scheme ~= 'file' then
        error("URI scheme is not 'file'")
    end

    local path = self.path
    -- Windows 路径处理
    if vim.fn.has('win32') == 1 then
        -- 处理网络路径
        if path:match('^//') then
            return path:gsub('/', '\\')
        end
        -- 处理驱动器号
        if path:match('^/[A-Za-z]:') then
            path = path:sub(2):gsub('/', '\\')
        end
        return path
    else
        return path
    end
end

function URI:parse_query()
    local params = {}
    for pair in self.query:gmatch('[^&]+') do
        local key, value = pair:match('^(.*)=(.*)$')
        if key then
            params[uri_decode(key)] = uri_decode(value)
        else
            params[uri_decode(pair)] = true
        end
    end
    return params
end

function URI:build_query(params)
    local parts = {}
    for k, v in pairs(params) do
        local key = uri_encode(tostring(k), true)
        if v == true then
            table.insert(parts, key)
        else
            table.insert(parts, key .. '=' .. uri_encode(tostring(v), true))
        end
    end
    self.query = table.concat(parts, '&')
end

function M.parse(value)
    local uri = setmetatable({}, URI)
    uri:parse(value)
    return uri
end

function M.file(path)
    local uri = setmetatable({}, URI)
    uri.scheme = 'file'
    uri.authority = ''

    -- 标准化路径
    path = path:gsub('\\', '/')
    if vim.fn.has('win32') == 1 then
        -- 处理网络路径
        if path:match('^//') then
            uri.path = path
        else
            if path:match('^%a:') then
                path = '/' .. path
            end
            uri.path = path
        end
    else
        uri.path = path
    end

    uri.path = uri:_normalize_path(uri.path)
    return uri
end

function M.join_path(uri, ...)
    local components = { ... }
    local new_path = uri.path

    for _, component in ipairs(components) do
        component = component:gsub('^/+', ''):gsub('/+$', '')
        if new_path:sub(-1) ~= '/' then
            new_path = new_path .. '/'
        end
        new_path = new_path .. component
    end

    new_path = uri:_normalize_path(new_path)

    return M.parse(uri:toString():gsub(uri.path, new_path))
end

-- 使用示例增强：
local uri = M.parse('https://user:pass@[fe80::1%eth0]:8080/path/../to/file.txt?q=1&test=true#frag')
print(uri.scheme) --> https
print(uri.host)   --> fe80::1%eth0
print(uri.port)   --> 8080
print(uri.path)   --> /to/file.txt

-- 查询参数解析
local query_params = uri:parse_query()
print(query_params.q)    --> "1"
print(query_params.test) --> "true"

-- 构建查询参数
uri:build_query({ a = '1', b = '2' })
print(uri.query) --> a=1&b=2

return M
