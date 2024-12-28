local Config = require('fittencode.config')
local Editor = require('fittencode.editor')
local Log = require('fittencode.log')

local Runtime = {}

local function get_comment_snippet()
    return Config.snippet.comment or ''
end

local function get_unit_test_framework()
    local tf = {}
    tf['c'] = 'C/C++'
    tf['cpp'] = tf['c']
    tf['java'] = 'Java'
    tf['python'] = 'Python'
    tf['javascript'] = 'JavaScript/TypeScript'
    tf['typescript'] = tf['javascript']
    return Config.unit_test_framework[tf[Editor.get_ft_language()]] or ''
end

function Runtime.resolve_variables_internal(v, e)
    local switch = {
        ['context'] = function()
            return { name = Editor.get_filename(), language = Editor.get_ft_language(), content = Editor.get_selected_text() }
        end,
        ['constant'] = function()
            return v.value
        end,
        ['message'] = function()
            return e and e[v.index] and e[v.index][v.property]
        end,
        ['selected-text'] = function()
            return Editor.get_selected_text()
        end,
        ['selected-location-text'] = function()
            return Editor.get_selected_location_text()
        end,
        ['filename'] = function()
            return Editor.get_filename()
        end,
        ['language'] = function()
            return Editor.get_ft_language()
        end,
        ['comment-snippet'] = function()
            return get_comment_snippet()
        end,
        ['unit-test-framework'] = function()
            local s = get_unit_test_framework()
            return s == 'Not specified' and '' or s
        end,
        ['selected-text-with-diagnostics'] = function()
            return Editor.get_selected_text_with_diagnostics({ diagnostic_severities = t.severities })
        end,
        ['errorMessage'] = function()
            return Editor.get_diagnose_info()
        end,
        ['errorLocation'] = function()
            return Editor.get_error_location()
        end,
        ['title-selected-text'] = function()
            return Editor.get_title_selected_text()
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
