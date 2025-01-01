local M = {}

---@param text string A UTF-8 string.
---@param delta number The delta based on characters
---@return number?
function M.characters_delta_to_columns(text, delta)
    -- 1. Calculate characters length of UTF-8 string, Generate a table of (utf8-index)
    -- 2. Count delta characters
    -- 3. Return the bytes length of the delta characters
end

return M
