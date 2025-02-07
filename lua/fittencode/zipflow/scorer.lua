local M = {}

function M.calculate(engine, opts)
    local score = 0

    -- 基础分
    score = score + engine.priority * 100

    -- 参数匹配度
    score = score + #engine:match_params(opts) * 10

    -- 资源偏好
    if opts.prefer == 'speed' then
        score = score + engine.performance.speed * 2
    end

    return score
end

return M
