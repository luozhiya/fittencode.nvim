local function ___generate_code()
local ___generated_code = {}
local ___env_orupm = _G.___env_orupm
local ___fn = ___env_orupm.___fn
local ___emit = function(s) ___generated_code[#___generated_code + 1] = s end
local function ___resolve_var(env, s)
    local resolved = nil
    if env[s] then
        resolved = env[s]
    elseif env.lastenv then
        resolved = ___resolve_var(env.lastenv, s)
    end
    if type(resolved) == "function" then
        return resolved()
    elseif type(resolved) == "string" or type(resolved) == "number" or type(resolved) == "table" then
        return resolved
    else
        return nil
    end
end
___emit([[<|system|>
]])
___emit([[Summarize the code at a high level (including goal and purpose) with an emphasis on its key functionality.
]])
___emit([[<|end|>
]])
___emit([[<|user|>
]])
___emit([[Below is the user's code context, which may be needed for subsequent inquiries.
]])
___emit([[## Code Summary
]])
___emit([[## Open Files
]])
local ___list_wajec = ___resolve_var(___env_orupm, 'openFiles')
assert(___fn.is_list(___list_wajec), "openFiles is not a list")
for ___index_qqjgn, ___element_veoza in ipairs(___list_wajec) do
local ___env_sbgbb = {}
___env_sbgbb.lastenv = ___env_orupm
___env_sbgbb.index = ___index_qqjgn -1
for k, v in pairs(___element_veoza) do
___env_sbgbb[k] = v
end
___emit([[### File: ]])
___emit(___resolve_var(___env_sbgbb, "name") )
___emit("\n")
___emit([[\`\`\`]])
___emit(___resolve_var(___env_sbgbb, "language") )
___emit("\n")
___emit(___resolve_var(___env_sbgbb, "content") )
___emit("\n")
___emit([[\`\`\`
]])

end
___emit([[<|end|>
]])
___emit([[<|assistant|>
]])
___emit([[Understood, you can continue to enter your question.
]])
___emit([[<|end|>
]])
___emit([[<|user|>
]])
___emit([[Break down and explain the following code in detail step by step, then summarize the code (emphasize its main function).
]])
___emit("\n")
___emit([[## Selected Code
]])
___emit([[\`\`\`
]])
___emit(___resolve_var(___env_orupm, "selectedText") )
___emit("\n")
___emit([[\`\`\`
]])
___emit([[<|end|>
]])
___emit([[<|assistant|>]])
return table.concat(___generated_code)
end
return ___generate_code()
