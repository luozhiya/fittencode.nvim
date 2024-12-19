local VM = {}

function VM.run(env, template)
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
