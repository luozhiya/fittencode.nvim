local Promise = require('fittencode.concurrency.promise')

local VSCode = {}
VSCode.__index = VSCode

function VSCode.new(options)
    local self = setmetatable({}, VSCode)
    self:__initialize(options)
    return self
end

function VSCode:__initialize(options)
    self.heart_beater = HeartBeater.new()
end

-- 异步获取项目级别的 Prompt
-- resolve: 超时返回 nil，否则返回提示内容
-- reject: 超时返回
---@return FittenCode.Concurrency.Promise
function VSCode:generate_prompt(buf, position)
    return Promise.race({
        Promise.async(function(resolve, reject)
            local result = self.engine:get_prompt_sync(buf, position)
            resolve(result)
        end),
        Promise.delay(self.timeout)
    })
end

-- 检测 LSP 客户端是否支持 `textDocument/documentSymbol`
-- * 1  代表可用
-- * 0  代表不可用
-- * -1 代表没有 LSP 客户端
function VSCode:get_file_lsp(buf)
    if not LspService.has_lsp_client(buf) then
        return -1
    end
    if LspService.supports_method('textDocument/documentSymbol', buf) then
        return 1
    end
    return 0
end

function VSCode:is_available(buf)
    local lsp = self.project_completion_service:get_file_lsp(buf)
    local _is_available = function(chosen)
        chosen = tonumber(chosen)
        local open = Config.use_project_completion.open
        local available = false
        local heart = self.heart_beater:get_status()
        if open == 'auto' then
            if chosen >= 1 and lsp == 1 and heart ~= 2 then
                available = true
            end
        elseif open == 'on' then
            if lsp == 1 and heart ~= 2 then
                available = true
            end
        elseif open == 'off' then
            available = false
        end
        return available
    end
    return self:get_chosen():forward(function(chosen)
        if _is_available(chosen) then
            return chosen
        else
            return Promise.reject()
        end
    end)
end

return VSCode
