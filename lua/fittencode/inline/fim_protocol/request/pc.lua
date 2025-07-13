local Promise = require('fittencode.base.promise')

---@return FittenCode.Promise<FittenCode.Inline.Prompt.MetaDatas>
local function build(shadow, position, uri)
    return Promise.resolved({
        pc_available = true,
        pc_prompt = '',
        pc_prompt_type = '0'
    })
end

return {
    build = build
}
