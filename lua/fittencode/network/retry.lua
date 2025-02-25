local DEFAULT_RETRY = {
    attempts = 3,
    delay = 1000, -- ms
    codes = { 408, 500, 502, 503, 504, 'ECONNRESET' }
}

local function should_retry(err, res)
    if type(err) == 'string' then
        return vim.tbl_contains(DEFAULT_RETRY.codes, err)
    end
    return vim.tbl_contains(DEFAULT_RETRY.codes, res and res.status)
end

local function fetch_with_retry(url, opts, attempt)
    attempt = attempt or 1
    local handle = M.fetch(url, opts)

    handle.run():catch(function(err, res)
        if attempt < opts.retry.attempts and should_retry(err, res) then
            uv.sleep(opts.retry.delay)
            return fetch_with_retry(url, opts, attempt + 1)
        end
        error(err)
    end)
end
