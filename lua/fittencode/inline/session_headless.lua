local HeadlessSession = {}
HeadlessSession.__index = HeadlessSession

function HeadlessSession.new(options)
    options = options or {}
    local self = setmetatable({}, HeadlessSession)
end
