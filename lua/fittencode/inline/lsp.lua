local NotifyInstallLSP = {}
NotifyInstallLSP.__index = NotifyInstallLSP

function NotifyInstallLSP.new(options)
    local obj = {
        last_notify_time = 0,
    }
    setmetatable(obj, NotifyInstallLSP)
    return obj
end

local M = {}

function M.notify_install_lsp(server_name)
end
