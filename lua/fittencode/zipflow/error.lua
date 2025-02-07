local M = {}

local errors = {
    ENGINE_NOT_FOUND = {
        code = 1001,
        template = 'No %s engine found for format: %s',
        advice = 'Check installed dependencies or try different format'
    },
    INVALID_LEVEL = {
        code = 2001,
        template = 'Invalid compression level: %d (valid range: %d-%d)',
        advice = 'Adjust the level parameter within supported range'
    }
}

function M.throw(error_key, ...)
    local err = errors[error_key]
    if not err then error('Unknown error key: ' .. error_key) end

    local msg = string.format(
        '[%d] %s\nAdvice: %s',
        err.code,
        string.format(err.template, ...),
        err.advice
    )

    error(msg, 3)
end

return M
