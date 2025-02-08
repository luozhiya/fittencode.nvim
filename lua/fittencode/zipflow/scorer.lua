local M = {}

function M.calculate(engine, opts)
    local score = 0

    -- 基础分
    score = score + engine.priority * 100

    -- 参数匹配度
    if engine['match_params'] then
        score = score + #engine:match_params(opts) * 10
    end

    -- 资源偏好
    if opts.prefer == 'speed' then
        score = score + engine.performance.speed * 2
    elseif opts.prefer == 'compression_ratio' then
        score = score + engine.performance.compression_ratio * 2
    end

    return score
end

return M
