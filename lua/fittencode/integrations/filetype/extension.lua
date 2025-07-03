--[[

对原有 nvim\runtime\lua\vim\filetype.lua 的修改：
- 删除 function 映射
- 简化逻辑，因为从 FittenCode 已经判断过一次类型了，以 FittenCode 类型为最大信度

]]


---@param ext string
---@return string
local function quick_match(ext)
    return extension[ext:lower()] or ''
end

return {
    quick_match = quick_match,
}
