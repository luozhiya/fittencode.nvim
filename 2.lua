local pattern = "<(fim_prefix|fim_suffix|fim_middle|%|%l*%|)>"

local text = [[
function test() {
    <fim_prefix>
    const x = <|variable|>;
    <fim_middle>
    return result;<fim_suffix>
}
]]

-- Find all tokens
for token in text:gmatch(pattern) do
    print("Found token:", token)
end

----------------------------------------
---
local str = "some <fim_prefix> text <|abc|> and <fim_middle> <fim_suffix> <|xyz|> done"

-- Replace <fim_prefix>, <fim_suffix>, <fim_middle>
str = str:gsub("<fim_prefix>", "")
str = str:gsub("<fim_suffix>", "")
str = str:gsub("<fim_middle>", "")

-- Replace <|letters|>
str = str:gsub("<|[a-z]*|>", "")

print(str) -- Output: some  text  and    done