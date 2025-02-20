local Promise = require('fittencode.concurrency.promise')
local HeartBeater = require('fittencode.inline.project_completion.versions.vscode.heart_beater')
local LspService = require('fittencode.functional.lsp_service')
local Config = require('fittencode.config')

local VSCode = {}
VSCode.__index = VSCode

function VSCode.new(options)
    local self = setmetatable({}, VSCode)
    self:__initialize(options)
    return self
end

function VSCode:__initialize(options)
    options = options or {}
    self.get_chosen = options.get_chosen
    assert(self.get_chosen, 'get_chosen is required')
    self.heart_beater = HeartBeater.new()
    self.engine = {
        default = nil,
        old = nil,
    }
end

function VSCode:generate_prompt(buf, position)
    local function which_engine(chosen)
        if chosen == '5' then
            return self.engine.old
        end
        return self.engine.default
    end
    return Promise.race({
        self:preflight(buf):forward(function(chosen)
            return Promise.async(function(resolve, reject)
                local e = which_engine(chosen)
                local prompt = e:get_prompt_sync(buf, position, {
                    order = chosen == '3' and 'reversed' or 'forward',
                })
                local meta = {
                    pc_available = true,
                    pc_prompt = prompt,
                    pc_prompt_type = chosen
                }
                resolve(meta)
            end)
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

function VSCode:preflight(buf)
    local lsp = self:get_file_lsp(buf)
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
    return self.get_chosen():forward(function(chosen)
        if _is_available(chosen) then
            return chosen
        else
            return Promise.reject()
        end
    end)
end

return VSCode
