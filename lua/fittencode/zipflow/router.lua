local registry = require('zipflow.registry')
local scorer = require('zipflow.scorer')

local M = {}

local function is_supported(engine, opts)
    if not engine then
        -- error("Engine is not provided")
        return false
    end

    if not engine.capabilities then
        -- error("Engine does not have capabilities")
        return false
    end

    local capabilities = engine.capabilities[opts.operation]
    if not capabilities then
        return false
    end

    local input_types = capabilities.input_types
    local formats = capabilities.formats

    if not input_types or not formats then
        -- error(("Engine capabilities for %s operation are incomplete"):format(opts.operation))
        return false
    end

    local match_input_type = vim.tbl_contains(input_types, '*') or vim.tbl_contains(input_types, opts.input_type)
    local match_format = vim.tbl_contains(formats, '*') or vim.tbl_contains(formats, opts.format)

    -- 解压可以不用匹配格式
    return match_input_type and (opts.operation == 'compress' or (opts.operation == 'decompress' and match_format))
end

function M.select_engine(opts)
    local candidates = {}

    -- 获取所有支持当前操作的引擎
    for _, engine in ipairs(registry.list_engines()) do
        if is_supported(engine, opts) then
            table.insert(candidates, engine)
        end
    end

    if #candidates == 0 then
        error(('No engine found for %s operation on %s'):format(opts.operation, opts.format))
    end

    -- 计算引擎得分
    local scored = {}
    for _, engine in ipairs(candidates) do
        table.insert(scored, {
            engine = engine,
            score = scorer.calculate(engine, opts)
        })
    end

    -- 选择最高分引擎
    table.sort(scored, function(a, b) return a.score > b.score end)
    return scored[1].engine
end

return M
