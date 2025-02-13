--[[

---------------------------------
--- `vim.fn.has`
---------------------------------

List of supported pseudo-feature names:
acl            |ACL| support.
bsd            BSD system (not macOS, use "mac" for that).
clipboard      |clipboard| provider is available.
fname_case     Case in file names matters (for Darwin and MS-Windows this is not present).
gui_running    Nvim has a GUI.
iconv          Can use |iconv()| for conversion.
linux          Linux system.
mac            MacOS system.
nvim           This is Nvim.
python3        Legacy Vim |python3| interface. |has-python|
pythonx        Legacy Vim |python_x| interface. |has-pythonx|
sun            SunOS system.
ttyin          input is a terminal (tty).
ttyout         output is a terminal (tty).
unix           Unix system.
vim_starting   True during |startup|.
win32          Windows system (32 or 64 bit).
win64          Windows system (64 bit).
wsl            WSL (Windows Subsystem for Linux) system.

vim.fn.has 实现细节
- nvim\share\nvim\runtime\lua\vim\_meta\vimfn.lua

---------------------------------
--- `vim.uv.os_uname().sysname`
---------------------------------

List of possible values:
Linux
Darwin (macOS)
FreeBSD
NetBSD
OpenBSD
SunOS (Solaris)
AIX
HP-UX
CYGWIN (Cygwin environment on Windows)
MINGW (MinGW environment on Windows)
Windows_NT (Windows)

uv_os_uname 实现细节
- src/win/util.c 通过 RtlGetVersion 以及注册表获取 Windows 版本信息
- src/unix/core.c 通过 uname 系统调用获取系统信息

--]]

local uname = vim.uv.os_uname()
local sysname = uname.sysname:lower()

local function windows_version()
    if uname.sysname == 'Windows_NT' then
        local version = uname.release
        if version:find('^10.0') then
            return 'Windows 10 or Windows Server 2016/2019/2022'
        elseif version:find('^6.3') then
            return 'Windows 8.1 or Windows Server 2012 R2'
        elseif version:find('^6.2') then
            return 'Windows 8 or Windows Server 2012'
        elseif version:find('^6.1') then
            return 'Windows 7 or Windows Server 2008 R2'
        elseif version:find('^6.0') then
            return 'Windows Vista or Windows Server 2008'
        elseif version:find('^5.2') then
            return 'Windows XP 64-Bit Edition or Windows Server 2003'
        elseif version:find('^5.1') then
            return 'Windows XP'
        else
            return 'Unknown Windows version'
        end
    else
        return 'Not running on Windows'
    end
end


local arch_aliases = {
    ['x86_64'] = 'x64',
    ['i386'] = 'x86',
    ['i686'] = 'x86', -- x86 compat
    ['aarch64'] = 'arm64',
    ['aarch64_be'] = 'arm64',
    ['armv8b'] = 'arm64', -- arm64 compat
    ['armv8l'] = 'arm64', -- arm64 compat
}
local M = {}

M.is_windows = function()
    return vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
end

M.is_linux = function()
    return vim.fn.has('linux') == 1
end

M.is_mac = function()
    return vim.fn.has('mac') == 1
end

M.is_unix = function()
    return vim.fn.has('unix') == 1
end

M.is_wsl = function()
    return vim.fn.has('wsl') == 1
end

M.is_bsd = function()
    return vim.fn.has('bsd') == 1
end

M.arch = function()
    return arch_aliases[uname.machine] or uname.machine
end

return M
