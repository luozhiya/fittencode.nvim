-- | 特性             | URLSearchParams     | URI                 |
-- |------------------|---------------------|---------------------|
-- | 标准             | -                   | RFC 3986            |
-- | 空格编码         | +                   | %20                 |
-- | 保留字符         | ;/?:@&=+$,          | 组件相关（如路径 /，查询 ? 等） |
-- | 编码范围         | 键和值              | 组件相关（如 scheme、path 等） |
-- | 多值参数         | 支持（key=1&key=2） | 不支持              |
-- | 编码函数复杂度   | 简单                | 复杂                |

-- URLSearchParams 的编码规则
-- 空格：编码为 +
-- 保留字符：以下字符需要编码：`; / ? : @ & = + $ ,`
-- 其他字符：
-- - 非字母数字字符（除 -_.~ 外）编码为 %XX
-- - 字母数字字符和 -_.~ 不编码

local URLSearchParams = {}
URLSearchParams.__index = URLSearchParams

-- 编码函数（符合 application/x-www-form-urlencoded 标准）
-- * 字符串中的所有非字母数字字符（除了 -, ., _, ~）转换为 %XX 格式的十六进制编码
-- * 空格字符转换为 +
---@param str string
---@return string
function URLSearchParams.encode_form_value(str)
    local pattern, _ = str:gsub(
        '([^%w%-%.%_%~ ])',
        function(c) return string.format('%%%02X', c:byte()) end
    ):gsub(' ', '+')
    return pattern
end

-- 解码函数
-- * + 解码为空格
-- * %XX 格式的十六进制编码转换为对应的字符
---@param str string
---@return string
function URLSearchParams.decode_form_value(str)
    local pattern, _ = str:gsub('+', ' ')
        :gsub(
            '%%(%x%x)',
            function(hex) return string.char(tonumber(hex, 16)) end
        )
    return pattern
end

---@param query? string 查询字符串，如 key1=value1&key2=value2&key3=value3
function URLSearchParams.new(query)
    local self = setmetatable({}, URLSearchParams)
    self._params = {}

    if type(query) == 'string' then
        self:_parse_query(query)
    elseif type(query) == 'table' then
        for k, v in pairs(query) do
            if type(v) == 'table' then
                for _, val in ipairs(v) do
                    self:append(k, val)
                end
            else
                self:append(k, v)
            end
        end
    end

    return self
end

-- 解析查询字符串
function URLSearchParams:_parse_query(query)
    if type(query) ~= 'string' or #query == 0 then
        error('Invalid query string provided for parsing')
    end
    for pair in query:gmatch('[^&]+') do
        -- 使用 match 提取键和值
        local key, value = pair:match('^(.-)=(.*)$')
        if key then
            -- 解码键和值
            self:append(URLSearchParams.decode_form_value(key), URLSearchParams.decode_form_value(value))
        elseif pair:match('^.+$') then
            -- 如果没有等号，但有键，则添加一个空值
            self:append(URLSearchParams.decode_form_value(pair), URLSearchParams.decode_form_value(''))
        end
    end
end

-- 添加键值对
function URLSearchParams:append(key, value)
    if not self._params[key] then
        self._params[key] = {}
    end
    table.insert(self._params[key], value)
end

-- 删除指定键的所有值
function URLSearchParams:delete(key)
    self._params[key] = nil
end

-- 获取指定键的第一个值
function URLSearchParams:get(key)
    if self._params[key] then
        return self._params[key][1]
    end
    return nil
end

-- 获取指定键的所有值
function URLSearchParams:get_all(key)
    return self._params[key] or {}
end

-- 检查是否存在指定键
function URLSearchParams:has(key)
    return self._params[key] ~= nil
end

-- 设置键值对（覆盖旧值）
function URLSearchParams:set(key, value)
    self._params[key] = { value }
end

-- 按键名排序
function URLSearchParams:sort()
    local sorted_keys = {}
    for k in pairs(self._params) do
        table.insert(sorted_keys, k)
    end
    table.sort(sorted_keys)

    local sorted_params = {}
    for _, k in ipairs(sorted_keys) do
        sorted_params[k] = self._params[k]
    end
    self._params = sorted_params
end

-- 生成查询字符串
function URLSearchParams:to_string()
    local parts = {}
    for key, values in pairs(self._params) do
        local encoded_key = URLSearchParams.encode_form_value(key)
        for _, value in ipairs(values) do
            table.insert(parts, encoded_key .. '=' .. URLSearchParams.encode_form_value(value))
        end
    end
    return table.concat(parts, '&')
end

-- 迭代器（支持 pairs 遍历）
function URLSearchParams:entries()
    local keys = {}
    for k in pairs(self._params) do
        table.insert(keys, k)
    end
    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key then
            return key, self._params[key]
        end
    end
end

-- 相同 key 的不会覆盖，只会追加到一个 table 中
function URLSearchParams:merge(other)
    for k, v in pairs(other._params) do
        if not self._params[k] then
            self._params[k] = {}
        end
        for _, value in ipairs(v) do
            table.insert(self._params[k], value)
        end
    end
end

return URLSearchParams
