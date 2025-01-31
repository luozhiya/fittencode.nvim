## Chrome URL

在 Chrome 浏览器（以及其他现代浏览器）中，**网址（URL）整体属于 URI（更准确说是 URL）**，而 URL 中的查询参数部分（`?` 后的内容）会用到 `URLSearchParams` 的逻辑。以下是详细说明：

---

### 一、整体结构：网址是 URI/URL
浏览器地址栏中的完整网址是一个 **URI（具体为 URL）**，符合 RFC 3986 标准。例如：
```
https://www.example.com:8080/path/to/file.html?name=John&age=30#section
```
- **URI 组件**：
  - Scheme（协议）：`https`
  - Authority（认证信息）：`www.example.com:8080`
  - Path（路径）：`/path/to/file.html`
  - Query（查询参数）：`name=John&age=30`
  - Fragment（锚点）：`section`

---

### 二、查询参数处理：URLSearchParams
浏览器通过 `URLSearchParams` API 专门处理 URL 中的 **查询参数部分**（`?` 后的内容）。例如：
```javascript
// 浏览器中的 JavaScript 代码
const url = new URL("https://example.com?name=John&age=30");
const params = new URLSearchParams(url.search);

// 操作查询参数
params.append("lang", "en");
console.log(params.toString()); // "name=John&age=30&lang=en"
```

---

### 三、关键区别
| 特性                | URI/URL                          | URLSearchParams                 |
|---------------------|----------------------------------|----------------------------------|
| **范围**            | 完整网址（协议、路径、参数等）   | 仅处理查询参数部分（`?` 后内容） |
| **编码规则**        | RFC 3986（复杂，区分组件）       | `application/x-www-form-urlencoded`（简单） |
| **用途**            | 标识资源位置                     | 操作查询参数                     |
| **浏览器实现**      | 通过 `URL` 类解析                | 通过 `URLSearchParams` 类操作    |

---

### 四、协同工作示例
1. **解析完整 URL**（URI）：
   ```javascript
   const url = new URL("https://example.com/search?q=hello&lang=en");
   ```

2. **提取并操作查询参数**（URLSearchParams）：
   ```javascript
   const params = new URLSearchParams(url.search);
   params.set("q", "world");
   params.append("page", "2");
   ```

3. **更新 URI 的查询参数**：
   ```javascript
   url.search = params.toString();
   console.log(url.href); 
   // "https://example.com/search?q=world&lang=en&page=2"
   ```

---

### 五、URI 和 URLSearchParams 的分工
1. **URI/URL**：
   - 负责协议、域名、路径、端口等全局信息。
   - 严格遵循 RFC 3986 编码规则（如路径中的 `/` 不编码，空格编码为 `%20`）。

2. **URLSearchParams**：
   - 仅处理查询参数（`?` 后的键值对）。
   - 遵循 `application/x-www-form-urlencoded` 编码规则（空格编码为 `+`，`/` 编码为 `%2F`）。

---

### 六、编码差异示例
| 参数值          | URI 编码（路径中） | URLSearchParams 编码 |
|-----------------|--------------------|-----------------------|
| `hello world`   | `hello%20world`    | `hello+world`         |
| `a/b`           | `a/b`（不编码）    | `a%2Fb`               |
| `key=value`     | `key%3Dvalue`      | `key%3Dvalue`         |

---

### 七、总结
- **网址本身是 URI/URL**：浏览器通过 `URL` 类解析和操作完整网址。
- **查询参数用 URLSearchParams**：专门处理 `?` 后的键值对，编码规则更简单。
- **二者协作**：`URL` 负责整体结构，`URLSearchParams` 专注参数操作。

这种分工使得浏览器既能处理复杂的 URI 结构，又能高效操作查询参数，同时保持编码规则的一致性。

## URI and URLSearchParams

**不完全一样**。尽管 `URLSearchParams` 处理的是 URI 的 query 组件（即 `?` 后的内容），但它们的编码规则和语义存在关键差异。以下是详细分析：

---

### 一、核心差异对比
| 特性                | URI Query 组件（RFC 3986）          | URLSearchParams（x-www-form-urlencoded） |
|---------------------|-------------------------------------|------------------------------------------|
| **编码标准**        | RFC 3986                            | `application/x-www-form-urlencoded`      |
| **空格编码**        | `%20`                               | `+`                                      |
| **保留字符**        | 仅 `?`、`#`、`&`、`=` 需编码        | 更多保留字符需编码（如 `/`、`:`、`@` 等）|
| **键值对语义**      | 无强制结构（可以是任意字符串）      | 严格键值对结构（`key=value&key2=value2`）|
| **多值参数**        | 无标准定义（依赖服务端解析逻辑）    | 支持多值（`key=1&key=2`）                |

---

### 二、关键差异详解
#### 1. **编码规则不同**
- **URI Query 组件**：
  - **允许字符**：除 `?`、`#`、`&`、`=` 外，大多数字符可直接使用。
  - **示例**：`?q=hello world` → 编码为 `?q=hello%20world`。
  
- **URLSearchParams**：
  - **保留字符更多**：包括 `/`、`:`、`@`、`+` 等均需编码。
  - **示例**：`q=hello world` → 编码为 `q=hello+world`。

#### 2. **语义差异**
- **URI Query 组件**：
  - **无强制结构**：查询字符串可以是任意格式（不一定是键值对）。
  - **示例**：`?query=foo&bar`（`bar` 无值）、`?name=John&Doe`（`Doe` 无键）。

- **URLSearchParams**：
  - **强制键值对**：必须符合 `key=value` 格式，无法表示无键或无值的参数。
  - **示例**：`name=John&Doe` → 解析为 `{ name: "John", Doe: "" }`。

#### 3. **多值参数处理**
- **URI Query 组件**：
  - 服务端自行决定是否支持多值（如 `?key=1&key=2`）。
  
- **URLSearchParams**：
  - 明确支持多值，提供 `getAll()` 方法获取所有值。

---

### 三、编码差异示例
| 参数内容          | URI Query 组件编码结果         | URLSearchParams 编码结果       |
|-------------------|--------------------------------|--------------------------------|
| `name=John Doe`   | `name=John%20Doe`             | `name=John+Doe`               |
| `path=a/b/c`      | `path=a/b/c`（不编码 `/`）    | `path=a%2Fb%2Fc`（编码 `/`）  |
| `key=@value`      | `key=@value`（不编码 `@`）    | `key=%40value`（编码 `@`）    |
| `empty=&`         | `empty=&`（保留 `&`）         | `empty=`（忽略无效参数）       |

---

### 四、为何存在差异？
1. **历史原因**：
   - `application/x-www-form-urlencoded` 是 HTML 表单提交的标准，早于现代 URI 规范。
   - URI 的 Query 组件更灵活，允许非键值对结构。

2. **应用场景不同**：
   - **URI Query**：通用资源定位，需支持复杂结构。
   - **URLSearchParams**：专注表单数据，强制键值对。

---

### 五、协作与转换
尽管规则不同，但二者可以协作：
```lua
-- URI 的 Query 组件 → URLSearchParams
local uri = URI.parse("https://example.com?q=hello%20world&lang=lua")
local params = URLSearchParams.new(uri.query) -- 自动解码 %20 为空格

-- 修改参数
params:set("q", "new value")

-- URLSearchParams → URI Query 组件
uri.query = params:toString() -- 空格编码为 +
print(uri:toString()) --> https://example.com?q=new+value&lang=lua
```

---

### 六、总结
- **规则不同**：URI Query 组件和 URLSearchParams 的编码规则、语义均有差异。
- **协作需注意**：
  - 从 URI Query 到 URLSearchParams 时，需解码（`%20` → 空格）。
  - 从 URLSearchParams 到 URI Query 时，需重新编码（空格 → `%20` 或 `+`，取决于场景）。
- **应用选择**：
  - 直接操作 URI 的 Query 字符串时，使用 **URI 编码规则**。
  - 处理表单数据或键值对参数时，使用 **URLSearchParams**。

## why no regex?

你的思路非常正确！Lua 的标准正则表达式确实存在局限性，无法完美处理 RFC 3986 的所有复杂情况。我们可以采用分步解析的方式来实现更精准的 URI 解析。以下是基于 RFC 3986 的分层解析实现：

```lua
local M = {}

-- RFC 3986 保留字符集
local reserved = {
    gen_delims = ":/?#[]@",
    sub_delims = "!$&'()*+,;="
}

-- 百分比解码函数
local function percent_decode(str)
    return str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

-- 主解析函数
function M.parse(uri)
    local components = {
        scheme = "",
        authority = "",
        path = "",
        query = "",
        fragment = "",
        userinfo = "",
        host = "",
        port = nil
    }

    -- Step 1: 分离 fragment
    local fragment_index = uri:find("#")
    if fragment_index then
        components.fragment = percent_decode(uri:sub(fragment_index + 1))
        uri = uri:sub(1, fragment_index - 1)
    end

    -- Step 2: 分离 query
    local query_index = uri:find("?")
    if query_index then
        components.query = percent_decode(uri:sub(query_index + 1))
        uri = uri:sub(1, query_index - 1)
    end

    -- Step 3: 解析 scheme
    local scheme_end = uri:find(":")
    if not scheme_end then
        error("Invalid URI: missing scheme")
    end
    components.scheme = uri:sub(1, scheme_end - 1):lower()
    uri = uri:sub(scheme_end + 1)

    -- Step 4: 处理 authority 和 path
    if uri:sub(1, 2) == "//" then
        -- 包含 authority 的 URI
        uri = uri:sub(3)
        local authority_end = uri:find("/") or (uri:find("#") or uri:find("?") or #uri + 1)
        components.authority = uri:sub(1, authority_end - 1)
        components.path = uri:sub(authority_end)
        
        -- 解析 authority 组件
        local authority = percent_decode(components.authority)
        local userinfo_index = authority:find("@")
        if userinfo_index then
            components.userinfo = authority:sub(1, userinfo_index - 1)
            authority = authority:sub(userinfo_index + 1)
        end

        -- 解析 host 和 port
        if authority:find("%b[]") then -- IPv6地址处理
            local host, port = authority:match("%[([%x:%]]+)%](:?%d*)")
            components.host = host or ""
            components.port = port ~= "" and tonumber(port:sub(2)) or nil
        else
            local host, port = authority:match("([^:]*)(:?.*)")
            components.host = host or ""
            components.port = port ~= "" and tonumber(port:sub(2)) or nil
        end
    else
        -- 无 authority 的 URI
        components.path = uri
    end

    -- Step 5: 路径处理
    components.path = percent_decode(components.path)
    
    -- Step 6: 路径标准化
    components.path = M.normalize_path(components.path)
    
    return components
end

-- 路径标准化函数
function M.normalize_path(path)
    local is_absolute = path:sub(1,1) == "/"
    local segments = {}
    
    for seg in path:gmatch("[^/]+") do
        if seg == "." then
            -- 保留必要的当前目录标记
            if #segments == 0 and not is_absolute then
                table.insert(segments, seg)
            end
        elseif seg == ".." then
            if #segments > 0 and segments[#segments] ~= ".." then
                table.remove(segments)
            else
                table.insert(segments, seg)
            end
        else
            table.insert(segments, seg)
        end
    end
    
    local normalized = table.concat(segments, "/")
    if is_absolute then normalized = "/"..normalized end
    if path:sub(-1) == "/" then normalized = normalized.."/" end
    
    return normalized
end

-- 测试用例
local test_uris = {
    "mailto:john.doe@example.com",
    "file:///C:/Users/文档/test.txt",
    "ftp://user:password@[2001:db8::1]:2121/path/to/file",
    "urn:isbn:0451450523",
    "http://example.com/path/../to/resource?q=test#section"
}

for _, uri in ipairs(test_uris) do
    print("\nParsing URI:", uri)
    local parsed = M.parse(uri)
    print("Scheme:", parsed.scheme)
    print("Authority:", parsed.authority)
    print("Path:", parsed.path)
    print("Query:", parsed.query)
    print("Fragment:", parsed.fragment)
    print("Host:", parsed.host)
    print("Port:", parsed.port)
end

return M
```

### 关键设计要点：

1. **分层解析架构**：
```lua
顺序解析：fragment → query → scheme → authority/path → 组件细化
```

2. **特殊协议处理**：
```lua
-- mailto: 处理
M.parse("mailto:name@domain.com") -->
{
    scheme = "mailto",
    path = "name@domain.com",
    authority = ""
}

-- URN 处理
M.parse("urn:isbn:123456789") -->
{
    scheme = "urn",
    path = "isbn:123456789"
}
```

3. **IPv6 地址支持**：
```lua
-- 自动识别方括号包裹的 IPv6 地址
M.parse("http://[2001:db8::1]:8080") -->
{
    host = "2001:db8::1",
    port = 8080
}
```

4. **路径标准化**：
```lua
M.normalize_path("/a/b/../c/./d") --> "/a/c/d"
M.normalize_path("../../rel/path") --> "../../rel/path"
```

5. **百分比编码处理**：
```lua
M.parse("http://ex%61mple.com/%7Euser") -->
{
    host = "example.com",
    path = "/~user"
}
```

### 各组件解析规则：

| 组件       | 解析规则                                                                 |
|------------|--------------------------------------------------------------------------|
| **Scheme** | 必须存在，符合 `[a-zA-Z][a-zA-Z0-9+-.]*` 格式                           |
| **Authority** | 可选，包含用户信息、主机和端口，支持 IPv6 地址                          |
| **Path**   | 自动标准化处理 `.` 和 `..`，保留尾部斜线                                |
| **Query**  | 保留原始格式，不强制键值对结构                                          |
| **Fragment** | 不参与 URI 的语义识别                                                   |

### 优势分析：
1. **兼容性更好**：正确处理各种边缘 case
   ```lua
   M.parse("file:///C:/test.txt") --> path = "/C:/test.txt"
   M.parse("ssh://[::1]/path") --> host = "::1"
   ```

2. **性能优化**：避免复杂正则带来的性能问题

3. **扩展性强**：方便添加特殊协议处理逻辑
   ```lua
   -- 添加特殊协议处理
   if components.scheme == "mailto" then
       components.email = components.path
       components.path = ""
   end
   ```

4. **RFC 合规**：严格遵循以下规范：
   - 组件分层解析（RFC 3986 §3）
   - 路径标准化（RFC 3986 §5.2.4）
   - IPv6 地址处理（RFC 3986 §3.2.2）

### 扩展建议：
1. **添加验证函数**：
```lua
function M.validate(components)
    -- 验证 scheme 格式
    if not components.scheme:match("^[a-zA-Z][a-zA-Z0-9+.-]*$") then
        return false, "Invalid scheme"
    end
    
    -- 验证端口范围
    if components.port and (components.port < 1 or components.port > 65535) then
        return false, "Invalid port number"
    end
    
    -- 其他验证逻辑...
    return true
end
```

2. **添加编码函数**：
```lua
function M.build(components)
    local parts = {}
    table.insert(parts, components.scheme .. ":")
    
    if components.authority ~= "" then
        table.insert(parts, "//" .. components.authority)
    end
    
    table.insert(parts, components.path)
    
    if components.query ~= "" then
        table.insert(parts, "?" .. components.query)
    end
    
    if components.fragment ~= "" then
        table.insert(parts, "#" .. components.fragment)
    end
    
    return table.concat(parts, "")
end
```

这种分步解析的方式虽然代码量稍多，但能更精确地处理各种 URI 类型，同时保持代码的可维护性和扩展性。

## `gen_delims` 和 `sub_delims` 的作用

在 URI 解析的实现中，`gen_delims`（通用分隔符）和 `sub_delims`（子组件分隔符）的定义是为了遵循 RFC 3986 标准中关于保留字符的规范。但在分步解析的实现中，这些字符集**未被直接使用**，原因如下：

---

### 一、分步解析的天然隔离性
分步解析通过 **结构化操作** 直接分离 URI 的各个组件（Scheme、Authority、Path 等），而无需显式依赖保留字符集。例如：
1. **Scheme 的提取**：通过查找第一个 `:` 字符直接分离 Scheme。
2. **Authority 的提取**：通过 `//` 标识符判断 Authority 的存在。
3. **Path/Query/Fragment 的分离**：通过 `?` 和 `#` 字符分割。

这种基于固定分隔符的分步操作，天然避开了对保留字符集的直接依赖。

---

### 二、保留字符的隐式处理
保留字符的作用已内嵌在解析逻辑中：
1. **Scheme 校验**：通过正则 `^[a-zA-Z][a-zA-Z0-9+-.]*$` 隐式排除了 `gen_delims` 中的非法字符。
2. **Authority 解析**：
   - `@` 分离用户信息。
   - `:` 分离主机和端口。
   - `[]` 包裹 IPv6 地址。
3. **Path 标准化**：自动处理 `.` 和 `..`，而 `/` 作为路径分隔符被保留。

---

### 三、编码/解码的上下文感知
在百分比编码和解码时，不同组件的保留字符规则不同，无法通过全局的 `gen_delims` 统一处理。例如：
- **Path 组件**：允许 `/` 字符。
- **Query 组件**：允许 `=` 和 `&`。
- **Fragment 组件**：允许 `#`。

若需严格遵循 RFC 3986，应为每个组件定义独立的编码规则：

```lua
-- 组件专用编码函数
local function encode_component(str, allowed_chars)
    return str:gsub(
        "([^%w%-%.%_%~"..allowed_chars.."])",
        function(c) return string.format("%%%02X", c:byte()) end
    )
end

-- 路径编码（允许 /）
local function encode_path(path)
    return encode_component(path, "/")
end

-- 查询参数编码（允许 ?=&）
local function encode_query(query)
    return encode_component(query, "?=&")
end
```

---

### 四、为何保留字符集仍被定义？
尽管在分步解析中未直接使用 `gen_delims`，但其存在仍有意义：
1. **代码可读性**：明确标识 RFC 3986 定义的保留字符。
2. **未来扩展**：为后续实现更精细的组件编码预留接口。
3. **文档作用**：提醒开发者注意保留字符的特殊性。

---

### 五、改进建议：严格模式实现
若需完全遵循 RFC 3986，可添加以下验证逻辑：

#### 1. Scheme 合法性验证
```lua
function validate_scheme(scheme)
    if not scheme:match("^[a-zA-Z][a-zA-Z0-9+.-]*$") then
        error("Invalid scheme: "..scheme)
    end
    -- 显式排除保留字符
    if scheme:find("[:/?#%[%]@]") then
        error("Scheme contains reserved characters")
    end
end
```

#### 2. Authority 组件验证
```lua
function validate_authority(authority)
    if authority:find("[?#]") then
        error("Authority contains invalid characters")
    end
end
```

#### 3. 路径保留字符检查
```lua
function validate_path(path)
    -- 允许 / 但禁止其他 gen_delims
    if path:find("[:%?#%[%]@]") then
        error("Path contains reserved characters")
    end
end
```

---

### 六、总结
| 方法           | 优点                      | 缺点                          |
|----------------|---------------------------|-------------------------------|
| **分步解析**   | 直观高效，避免复杂正则    | 未显式处理保留字符            |
| **保留字符集** | 符合 RFC 规范，可扩展性强 | 需为每个组件实现独立处理逻辑  |

在现有分步解析实现中，保留字符通过 **结构化操作和隐式规则** 被正确处理。若需严格合规，应补充组件级的保留字符验证和编码规则，此时 `gen_delims` 和 `sub_delims` 将发挥关键作用。