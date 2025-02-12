local OPL = require('fittencode.open_promot_language.opl')
local Log = require('fittencode.log')

---@class FittenCode.VM
local VM = {}

VM.__index = VM

---@return FittenCode.VM
function VM:new()
    local obj = {}
    setmetatable(obj, self)
    return obj
end

---@param env table
---@param template string
---@return string?
function VM:run(env, template)
    local function sample()
        local env_name, code = OPL.CompilerRunner(env, template)
        local stdout, stderr = OPL.CodeRunner(env_name, env, nil, code)
        if stderr then
            Log.error('Error evaluating template: {}', stderr)
        else
            return stdout
        end
    end
    return sample()
end

return VM
