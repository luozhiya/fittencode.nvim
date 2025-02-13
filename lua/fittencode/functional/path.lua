--[[

Path 模块的设计区别于 Node.js 的模块，可以提供更加灵活的接口
- 路径按平台分类
- 在不同的平台上，路径还可以有不同的形式
- 路径可以跨平台转换 (仅作斜杠和反斜杠的转换)
  - 因为做更深层次的转换意义不大？比如 /usr/bin 转成 C:\\Windows\\System32 ? 这是没有什么意义的
  - 有转换意义可能是 wsl 路径转换，比如 /mnt/c/Windows/System32 转成 C:\\Windows\\System32
- 路径可以智能拼接
- 路径可以智能解析

local p = M

---------------------------------------
-- 使用 new/windows/posix 方法创建路径对象
---------------------------------------

print(p.new('', 'windows'):join('C:\\Program Files'))    -- C:\Program Files
print(p.windows():join('C:\\Program Files'):to('posix')) -- 输出 C:/Program Files
print(p.windows('C:\\Program Files'):to('posix'))        -- 输出 C:/Program Files
print(p.windows('C:\\Program Files'):flip_slashes())     -- 输出 C:/Program Files

---------------------------------------
-- 混合平台路径操作
---------------------------------------

local project_path = p.new('src/components', 'posix')
    :to('windows')
    :join('..\\utils')
    :normalize()
print(project_path) -- 输出 src\utils

local res = p.new('/usr/local')
    :join('bin/neovim')
    :join('../share/nvim/runtime')
    :normalize()
print(res) -- 输出 /usr/local/bin/share/nvim/runtime

--]]

local Platform = require('fittencode.functional.platform')
