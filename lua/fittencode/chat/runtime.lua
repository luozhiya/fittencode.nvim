local Config = require('fittencode.config')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')

local Runtime = {}

local function comment_snippet()
    return Config.snippet.comment or ''
end

local function unit_test_framework()
    local tf = {}
    tf['c'] = 'C/C++'
    tf['cpp'] = tf['c']
    tf['java'] = 'Java'
    tf['python'] = 'Python'
    tf['javascript'] = 'JavaScript/TypeScript'
    tf['typescript'] = tf['javascript']
    return Config.unit_test_framework[tf[Editor.language_id()]] or ''
end

function Runtime.resolve_variables_internal(v, e)
    local switch = {
        ['context'] = function()
            return { name = Editor.filename(), language = Editor.language_id(), content = Editor.content() }
        end,
        ['constant'] = function()
            return v.value
        end,
        ['message'] = function()
            return e and e[v.index] and e[v.index][v.property]
        end,
        ['selected-text'] = function()
            return Editor.selected_text()
        end,
        ['selected-location-text'] = function()
            return Editor.selected_location_text()
        end,
        ['filename'] = function()
            return Editor.filename()
        end,
        ['language'] = function()
            return Editor.language_id()
        end,
        ['comment-snippet'] = function()
            return comment_snippet()
        end,
        ['unit-test-framework'] = function()
            local s = unit_test_framework()
            return s == 'Not specified' and '' or s
        end,
        ['selected-text-with-diagnostics'] = function()
            return Editor.selected_text_with_diagnostics({ diagnostic_severities = v.severities })
        end,
        ['errorMessage'] = function()
            return Editor.diagnose_info()
        end,
        ['errorLocation'] = function()
            return Editor.error_location()
        end,
        ['title-selected-text'] = function()
            return Editor.title_selected_text()
        end,
        ['terminal-text'] = function()
            Log.error('Not implemented for terminal-text')
            return ''
        end
    }
    return switch[v.type]()
end

function Runtime.resolve_variables(variables, e)
    local n = {
        messages = e.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == e.time then
            if n[v.name] == nil then
                local s = Runtime.resolve_variables_internal(v, { messages = e.messages })
                n[v.name] = s
            else
                Log.error('Variable {} is already defined', v.name)
            end
        end
    end
    return n
end

return Runtime
