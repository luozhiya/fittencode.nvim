local SI = require('fittencode.sourceinsight')

local DEFAULT_CONTEXT_THRESHOLD = 100
local FIM_MIDDLE_TOKEN = '<fim_middle>'

local M = {}

function M.build(shadow, position, threshold)
    local fragment = SI.get_fragment({ shadow = shadow, position = position, threshold = threshold or DEFAULT_CONTEXT_THRESHOLD })
    return table.concat({ fragment[1], FIM_MIDDLE_TOKEN, fragment[2] })
end

return M
