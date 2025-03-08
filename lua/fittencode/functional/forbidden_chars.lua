-- Windows禁止的文件名字符
local windows_forbidden_chars = {
    ['<'] = true,
    ['>'] = true,
    [':'] = true,
    ['\"'] = true,
    ['/'] = true,
    ['\\'] = true,
    ['|'] = true,
    ['?'] = true,
    ['*'] = true
}

-- Linux禁止的文件名字符（主要为路径分隔符）
local linux_forbidden_chars = {
    ['/'] = true
}

-- Linux中不推荐使用的文件名字符（虽然不是严格禁止，但可能会导致命令行解析错误）
local linux_unrecommended_chars = {
    ['\0'] = true, -- 空字符
    ['\n'] = true  -- 换行符
}
