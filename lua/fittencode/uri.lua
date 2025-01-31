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

-- RFC 3986 定义组件字符集
local component_chars = {
    unreserved = 'a-zA-Z0-9%-._~',
    gen_delims = ':/?#[]@',
    sub_delims = "!$&'()*+,;="
}

local function component_encoder(safe_chars)
    return function(str)
        return str:gsub(
            '([^' .. safe_chars .. '])',
            function(c)
                return string.format('%%%02X', c:byte())
            end
        )
    end
end

-- 各组件专用编码器
local encode = {
    scheme = component_encoder('a-zA-Z0-9%+%-%.'),
    authority = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':%'),
    path_segment = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':@'),
    query = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':@/?%'),
    fragment = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':@/?%')
}

local function percent_decode(str)
    return str:gsub(
        '%%(%x%x)',
        function(hex)
            return string.char(tonumber(hex, 16))
        end
    )
end

local URI = {}
URI.__index = URI

function URI:parse(uri_string)
    -- RFC 3986 标准分解正则表达式
    local pattern = '^([^:/?#]+):(?://([^/?#]*))?([^?#]*)(?:%?([^#]*))?(?:#(.*))?$'
    local scheme, authority, path, query, fragment = uri_string:match(pattern)

    if not scheme then
        error('Invalid URI: ' .. uri_string)
    end

    self.scheme = scheme:lower()
    self.authority = authority and percent_decode(authority) or ''
    self.path = self:_normalize_path(percent_decode(path or ''))
    self.query = query and percent_decode(query) or ''
    self.fragment = fragment and percent_decode(fragment) or ''

    self:_parse_authority()
end

function URI:_parse_authority()
    self.userinfo, self.host, self.port = nil, nil, nil
    if self.authority == '' then return end

    -- 提取用户信息
    local userinfo, rest = self.authority:match('^(.*)@(.*)$')
    if userinfo then
        self.userinfo = userinfo
    else
        rest = self.authority
    end

    -- 处理 IPv6 地址
    if rest:find('^%[') then
        local ipv6, port = rest:match('^%[(.+)%](:?%d*)$')
        if not ipv6 then error('Invalid IPv6 address') end
        self.host = '[' .. ipv6 .. ']'
        self.port = port ~= '' and tonumber(port:sub(2)) or nil
    else
        -- 普通主机和端口
        local host, port = rest:match('^([^:]*)(:?%d*)$')
        self.host = host ~= '' and host or nil
        self.port = port ~= '' and tonumber(port:sub(2)) or nil
    end
end

function URI:_normalize_path(path)
    -- RFC 3986 路径规范化
    if path == '' then return '' end

    local is_absolute = path:sub(1, 1) == '/'
    local segments = {}

    for seg in path:gmatch('[^/]+') do
        if seg == '.' then
            -- 保留前导的当前目录
            if #segments == 0 and not is_absolute then
                table.insert(segments, seg)
            end
        elseif seg == '..' then
            if #segments > 0 and segments[#segments] ~= '..' then
                table.remove(segments)
            else
                table.insert(segments, seg)
            end
        else
            table.insert(segments, seg)
        end
    end

    local normalized = table.concat(segments, '/')
    if is_absolute then normalized = '/' .. normalized end
    if path:sub(-1) == '/' then normalized = normalized .. '/' end

    return normalized
end

function URI:build_authority()
    local parts = {}
    if self.userinfo then
        table.insert(parts, encode.authority(self.userinfo) .. '@')
    end
    if self.host then
        -- IPv6 需要保留方括号
        if self.host:find(':') and not self.host:find('^%[') then
            table.insert(parts, '[' .. self.host .. ']')
        else
            table.insert(parts, self.host)
        end
    end
    if self.port then
        table.insert(parts, ':' .. tostring(self.port))
    end
    return table.concat(parts, '')
end

function URI:to_string()
    local parts = {
        encode.scheme(self.scheme) .. ':'
    }

    -- Authority 处理
    local authority = self:build_authority()
    if authority ~= '' then
        table.insert(parts, '//' .. authority)
    elseif self.scheme == 'file' then
        table.insert(parts, '//')
    end

    -- Path 处理
    local path = self.path
    if path ~= '' then
        if authority ~= '' and path:sub(1, 1) ~= '/' then
            path = '/' .. path
        end
        local encoded_segments = {}
        for seg in path:gmatch('[^/]+') do
            table.insert(encoded_segments, encode.path_segment(seg))
        end
        path = table.concat(encoded_segments, '/')
        if path:sub(1, 1) == '/' then path = '/' .. path end
        table.insert(parts, path)
    end

    -- Query 和 Fragment
    if self.query ~= '' then
        table.insert(parts, '?' .. encode.query(self.query))
    end
    if self.fragment ~= '' then
        table.insert(parts, '#' .. encode.fragment(self.fragment))
    end

    return table.concat(parts, '')
end

-- 文件 URI 特殊处理
function URI:to_file_path()
    if self.scheme ~= 'file' then error('Not a file URI') end

    local path = self.path
    -- 处理 Windows 驱动器
    if path:match('^/[A-Za-z]:') then
        path = path:sub(2):gsub('/', '\\')
        -- 处理 UNC 路径
    elseif path:match('^//') then
        path = path:gsub('/', '\\')
    else
        path = path:gsub('/', (vim.fn.has('win32') == 1) and '\\' or '/')
    end

    return path
end

-- 查询参数处理
function URI:parse_query()
    local params = {}
    for pair in self.query:gmatch('([^&]+)') do
        local key, value = pair:match('^([^=]*)=(.*)$')
        if key then
            params[percent_decode(key)] = percent_decode(value)
        else
            params[percent_decode(pair)] = ''
        end
    end
    return params
end

-- 增强的构造方法
function M.parse(str)
    local uri = setmetatable({}, URI)
    uri:parse(str)
    return uri
end

function M.build(options)
    local uri = setmetatable({}, URI)
    uri.scheme = options.scheme:lower()
    uri.userinfo = options.userinfo
    uri.host = options.host
    uri.port = options.port
    uri.path = uri:_normalize_path(options.path or '')
    uri.query = options.query or ''
    uri.fragment = options.fragment or ''
    return uri
end

return M
