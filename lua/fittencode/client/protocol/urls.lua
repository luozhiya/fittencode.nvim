---@class FittenCode.Protocol.URLs
local M = {}

local URLs = {
    -- Account
    register = {
        method = 'OPENLINK',
        url = 'https://fc.fittentech.com/',
        query = {
            ref = { '{{platform_info}}' },
        }
    },
    -- 通过第三方注册后需要调用此接口，后台做统计
    register_cvt = {
        method = 'GET',
        url = 'https://fc.fittentech.com/cvt/register'
    },
    question = {
        method = 'OPENLINK',
        url = 'https://code.fittentech.com/assets/images/blog/QR.jpg'
    },
    tutor = {
        method = 'OPENLINK',
        url = 'https://code.fittentech.com/desc-vim'
    },
    try = {
        method = 'OPENLINK',
        url = 'https://code.fittentech.com/try'
    },
}

for _, url in pairs(URLs) do
    url.type = 'url'
end

M.__index = function(_, k)
    if URLs[k] then
        return vim.deepcopy(URLs[k])
    end
end
setmetatable(M, M)

return M
