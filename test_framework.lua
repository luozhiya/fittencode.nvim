-- test_framework.lua
local M = {}
local current_suite = {}

-- 获取测试文件参数（跳过nvim -l参数）
local test_files = {}
for i = 3, #vim.v.argv do
    table.insert(test_files, vim.v.argv[i])
end

local function describe(desc, fn)
    table.insert(current_suite, {
        desc = desc,
        tests = {},
        before_each = function() end
    })
    fn()
    current_suite[#current_suite] = nil -- 修复套件污染问题
end

local function it(name, fn)
    local suite = current_suite[#current_suite]
    if not suite then
        error("it() must be called inside describe()")
    end
    table.insert(suite.tests, {name = name, fn = fn})
end

local function before_each(fn)
    local suite = current_suite[#current_suite]
    if not suite then
        error("before_each() must be called inside describe()")
    end
    suite.before_each = fn
end

local function load_tests()
    for _, file in ipairs(test_files) do
        local ok, err = pcall(function()
            -- 创建包含框架函数的独立环境
            local env = {
                describe = describe,
                it = it,
                before_each = before_each,
                assert = assert -- 注入标准断言函数
            }

            -- 设置环境并执行文件
            local chunk = loadfile(file)
            if chunk then
                setfenv(chunk, setmetatable(env, {__index = _G}))
                chunk()
            end
        end)

        if not ok then
            table.insert(current_suite, {
                desc = "File Load Error",
                tests = {{
                    name = file,
                    fn = function() error(err) end
                }}
            })
        end
    end
end

local function run_tests()
    load_tests()

    local results = { passed = 0, failed = 0, failures = {} }

    for _, suite in ipairs(current_suite) do
        for _, test in ipairs(suite.tests) do
            local test_name = ("[%s] %s"):format(suite.desc, test.name)

            local ok, err = pcall(function()
                suite.before_each()
                test.fn()
            end)

            if ok then
                results.passed = results.passed + 1
            else
                results.failed = results.failed + 1
                table.insert(results.failures, ("%s: %s"):format(test_name, err))
            end
        end
    end

    return results
end

-- 主执行流程
vim.schedule(function()
    local results = { passed = 0, failed = 0, failures = {} }

    local ok, err = pcall(function()
        local tmp = run_tests()
        results = tmp
    end)

    if not ok then
        results = {
            passed = 0,
            failed = 1,
            failures = { "Framework error: " .. tostring(err) }
        }
    end

    print("TEST_RESULTS:" .. vim.json.encode(results))
    vim.cmd("qall!")
end)

return M
