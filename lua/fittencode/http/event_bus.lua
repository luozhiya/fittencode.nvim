local event = require('http.event_bus')

local function emit_event(name, data)
    event.emit('http:' .. name, {
        url = data.url,
        method = data.method,
        timestamp = uv.hrtime(),
        data = data
    })
end

-- 在关键节点触发事件
emit_event('request_start', { url = url, opts = opts })
emit_event('response_chunk', { size = #chunk })
