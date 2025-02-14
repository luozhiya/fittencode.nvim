--[[

Path 模块的设计区别于 Node.js 的模块，可以提供更加灵活的接口
- 路径按平台分类
- 在不同的平台上，路径还可以有不同的形式
- 路径可以跨平台转换 (仅作斜杠和反斜杠的转换)
  - 因为做更深层次的转换意义不大？比如 /usr/bin 转成 C:\\Windows\\System32 ? 这是没有什么意义的
  - 有转换意义可能是 wsl 路径转换，比如 /mnt/c/Windows/System32 转成 C:\\Windows\\System32
- 路径可以智能拼接
- 路径可以智能解析

--]]

local M = {}



function M.join(...)
    print(vim.inspect({...}))
    local x = Path.new():join(...):normalize()
    print(vim.inspect(x))
    return x:tostring()
end

function M.normalize(path)
    return Path.new(path):normalize():tostring()
end

print(M.join('E:/DataCenter/onWorking/fittencode.nvim/lua/fittencode/extension.lua', '../../../'))

return M
