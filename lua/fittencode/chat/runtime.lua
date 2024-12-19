local Config = require('fittencode.config')
local editor = require('fittencode.editor')
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
    return Config.unit_test_framework[tf[editor.get_ft_language()]] or ''
end

function Runtime.resolve_variables_internal(v, tm)
    local function get_value(t, e)
        local switch = {
            ['context'] = function()
                return { name = editor.get_filename(), language = editor.get_ft_language(), content = editor.get_selected_text() }
            end,
            ['constant'] = function()
                return t.value
            end,
            ['message'] = function()
                return e and e[t.index] and e[t.index][t.property]
            end,
            ['selected-text'] = function()
                return editor.get_selected_text()
            end,
            ['selected-location-text'] = function()
                return editor.get_selected_location_text()
            end,
            ['filename'] = function()
                return editor.get_filename()
            end,
            ['language'] = function()
                return editor.get_ft_language()
            end,
            ['comment-snippet'] = function()
                return get_comment_snippet()
            end,
            ['unit-test-framework'] = function()
                local s = get_unit_test_framework()
                return s == 'Not specified' and '' or s
            end,
            ['selected-text-with-diagnostics'] = function()
                return editor.get_selected_text_with_diagnostics({ diagnostic_severities = t.severities })
            end,
            ['errorMessage'] = function()
                return editor.get_diagnose_info()
            end,
            ['errorLocation'] = function()
                return editor.get_error_location()
            end,
            ['title-selected-text'] = function()
                return editor.get_title_selected_text()
            end,
            ['terminal-text'] = function()
                Log.error('Not implemented for terminal-text')
                return ''
            end
        }
        return switch[t.type]
    end
    return get_value(type, tm)
end

function Runtime.resolve_variables(variables, tm)
    local n = {
        messages = tm.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == tm.time then
            if n[v.name] == nil then
                local s = Runtime.resolve_variables_internal(v, { messages = tm.messages })
                n[v.name] = s
            else
                Log.error('Variable {} is already defined', v.name)
            end
        end
    end
    return n
end

return Runtime
