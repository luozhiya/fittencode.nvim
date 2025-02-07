local registry = require('zipflow.registry')
local scorer = require('zipflow.scorer')

local M = {}

function M.select_engine(opts)
    local candidates = {}

    -- 获取所有支持当前操作的引擎
    for _, engine in ipairs(registry.list_engines()) do
        if engine:supports(opts.operation, opts.format) then
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
