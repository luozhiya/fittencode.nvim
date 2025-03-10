--[[

覆盖原有的 init/destroy 方法，增加一个 _is_initialized 方法，用于判断模块是否已经初始化。
用于在其他地方判断模块是否已经初始化，避免重复初始化。

]]
local function make_stateful(module)
    -- 防止重复包装
    if module._wrapped_initialized then
        return module
    end
    module._wrapped_initialized = true

    local initialized = false
    local p_init = module.init
    local p_destroy = module.destroy

    -- 包装init方法，处理参数和返回值
    function module.init(...)
        if initialized then
            return
        end
        initialized = true
        if p_init then
            return p_init(...)
        end
    end

    -- 包装destroy方法，处理参数和返回值
    function module.destroy(...)
        if not initialized then
            return
        end
        initialized = false
        if p_destroy then
            return p_destroy(...)
        end
    end

    -- 添加初始化状态检查方法
    function module._is_initialized()
        return initialized
    end

    return module
end

return {
    make_stateful = make_stateful
}
