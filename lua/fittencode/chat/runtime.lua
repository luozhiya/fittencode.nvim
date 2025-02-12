local Config = require('fittencode.config')
local EditorStateMonitor = require('fittencode.chat.editor_state_monitor')
local Editor = require('fittencode.document.editor')
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

function Runtime.resolve_variables_internal(variables, messages)
    local buf = EditorStateMonitor.active_text_editor()
    if not buf then
        return
    end
    local switch = {
        ['context'] = function()
            return { name = Editor.filename(buf), language = Editor.language_id(buf), content = Editor.content(buf) }
        end,
        ['constant'] = function()
            return variables.value
        end,
        ['message'] = function()
            return messages and messages[variables.index] and messages[variables.index][variables.property]
        end,
        ['selected-text'] = function()
            return EditorStateMonitor.selected_text()
        end,
        ['selected-location-text'] = function()
            return EditorStateMonitor.selected_location_text()
        end,
        ['filename'] = function()
            return Editor.filename(buf)
        end,
        ['language'] = function()
            return Editor.language_id(buf)
        end,
        ['comment-snippet'] = function()
            return comment_snippet()
        end,
        ['unit-test-framework'] = function()
            local s = unit_test_framework()
            return s == 'Not specified' and '' or s
        end,
        ['selected-text-with-diagnostics'] = function()
            return EditorStateMonitor.selected_text_with_diagnostics({ diagnostic_severities = variables.severities })
        end,
        ['errorMessage'] = function()
            return EditorStateMonitor.diagnose_info()
        end,
        ['errorLocation'] = function()
            return EditorStateMonitor.error_location()
        end,
        ['title-selected-text'] = function()
            return EditorStateMonitor.title_selected_text()
        end,
        ['terminal-text'] = function()
            Log.error('Not implemented for terminal-text')
            return ''
        end
    }
    return switch[variables.type]()
end

function Runtime.resolve_variables(variables, e)
    local n = {
        messages = e.messages,
    }
    for _, v in ipairs(variables) do
        if v.time == e.time then
            if n[v.name] == nil then
                local s = Runtime.resolve_variables_internal(v, { messages = e.messages })
                if not s then
                    Log.warn('Failed to resolve variable {}', v.name)
                end
                n[v.name] = s
            else
                Log.warn('Variable {} is already defined', v.name)
            end
        end
    end
    return n
end

return Runtime
