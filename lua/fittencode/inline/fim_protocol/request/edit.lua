local Promise = require('fittencode.base.promise')

---@return FittenCode.Promise<FittenCode.Inline.Prompt.MetaDatas>
local function build(mode)
    return Promise.resolved({
        edit_mode = mode == 'editcmp' and 'true' or nil,
        edit_mode_history = '',
        -- Edit mode trigger type
        -- 默认为 0，表示手动触发
        -- 0 手动快捷键触发
        -- 1 当 inccmp 没有产生补全，或者产生的补全与现有内容一致重复时触发
        -- 2 当一个 editcmp accept 之后连续触发
        edit_mode_trigger_type = '0'
    })
end

return {
    build = build
}
