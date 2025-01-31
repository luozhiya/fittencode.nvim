local config = {
    max_connections = 10,
    timeout = 30000,
    user_agent = 'nvim-http/1.0',
    ssl_verify = true,
    dns_cache = {}
}

local function setup(opts)
    config = vim.tbl_deep_extend('force', config, opts or {})

    -- 初始化 DNS 缓存清理定时器
    uv.new_timer():start(0, 60 * 60 * 1000, function()
        config.dns_cache = {}
    end)
end

-- lua/http/init.lua
local M = {
    backends = {},
    config = {
        backend = "curl", -- 默认使用curl命令行
        timeout = 30000,
        max_redirects = 5,
        user_agent = "nvim-http/1.0"
    }
}

local backends = {
    curl = require("http.backends.curl"),
    libcurl = require("http.backends.libcurl")
}

-- 统一请求参数规范
local RequestSpec = {
    url = { required = true, type = "string" },
    method = { default = "GET", type = "string" },
    headers = { type = "table" },
    body = { type = { "string", "function" } },
    timeout = { type = "number" },
    follow_redirects = { type = "boolean" },
    validate_ssl = { type = "boolean" }
}

local function validate_spec(spec)
    -- 参数验证逻辑...
end

function M.setup(config)
    M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

function M.request(spec, callback)
    validate_spec(spec)
    local backend = backends[M.config.backend]
    return backend.request(spec, callback)
end

-- 快捷方法
local function create_method(method)
    return function(url, opts, callback)
        return M.request(vim.tbl_extend("force", {
            url = url,
            method = method
        }, opts or {}), callback)
    end
end

M.get = create_method("GET")
M.post = create_method("POST")
M.put = create_method("PUT")
M.delete = create_method("DELETE")
M.patch = create_method("PATCH")

return M