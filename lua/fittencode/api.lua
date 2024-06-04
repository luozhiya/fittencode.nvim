local ActionsEngine = require('fittencode.engines.actions')
local InlineEngine = require('fittencode.engines.inline')
local Engines = require('fittencode.engines')
local Log = require('fittencode.log')
local Sessions = require('fittencode.sessions')

local M = {}

M.api = {
  ---@param username? string
  ---@param password? string
  login = function(username, password)
    Sessions.login(username, password)
  end,
  logout = function()
    Sessions.logout()
  end,
  register = function()
    Sessions.register()
  end,
  ---@param level integer @one of the `vim.log.levels` values
  set_log_level = function(level)
    Log.set_level(level)
  end,
  ---@return integer, integer
  get_current_status = function()
    return Engines.get_status()
  end,
  triggering_completion = function()
    InlineEngine.triggering_completion()
  end,
  ---@return boolean
  has_suggestions = function()
    return InlineEngine.has_suggestions()
  end,
  accept_all_suggestions = function()
    InlineEngine.accept_all_suggestions()
  end,
  accept_line = function()
    InlineEngine.accept_line()
  end,
  accept_word = function()
    InlineEngine.accept_word()
  end,
  accept_char = function()
    InlineEngine.accept_char()
  end,
  revoke_line = function()
    InlineEngine.revoke_line()
  end,
  revoke_word = function()
    InlineEngine.revoke_word()
  end,
  revoke_char = function()
    InlineEngine.revoke_char()
  end,
  ---@param opts? ActionOptions
  document_code = function(opts)
    return ActionsEngine.document_code(opts)
  end,
  ---@param opts? ActionOptions
  edit_code = function(opts)
    return ActionsEngine.edit_code(opts)
  end,
  ---@param opts? ActionOptions
  explain_code = function(opts)
    return ActionsEngine.explain_code(opts)
  end,
  ---@param opts? ActionOptions
  find_bugs = function(opts)
    return ActionsEngine.find_bugs(opts)
  end,
  ---@param opts? GenerateUnitTestOptions
  generate_unit_test = function(opts)
    return ActionsEngine.generate_unit_test(opts)
  end,
  ---@param opts? ImplementFeaturesOptions
  implement_features = function(opts)
    return ActionsEngine.implement_features(opts)
  end,
  ---@param opts? ImplementFeaturesOptions
  implement_functions = function(opts)
    return ActionsEngine.implement_functions(opts)
  end,
  ---@param opts? ImplementFeaturesOptions
  implement_classes = function(opts)
    return ActionsEngine.implement_classes(opts)
  end,
  ---@param opts? ActionOptions
  optimize_code = function(opts)
    return ActionsEngine.optimize_code(opts)
  end,
  ---@param opts? ActionOptions
  refactor_code = function(opts)
    return ActionsEngine.refactor_code(opts)
  end,
  ---@param opts? ActionOptions
  identify_programming_language = function(opts)
    return ActionsEngine.identify_programming_language(opts)
  end,
  ---@param opts? ActionOptions
  analyze_data = function(opts)
    return ActionsEngine.analyze_data(opts)
  end,
  ---@param opts? TranslateTextOptions
  translate_text = function(opts)
    return ActionsEngine.translate_text(opts)
  end,
  ---@param opts? TranslateTextOptions
  translate_text_into_chinese = function(opts)
    opts.target_language = 'Chinese'
    return ActionsEngine.translate_text(opts)
  end,
  ---@param opts? TranslateTextOptions
  translate_text_into_english = function(opts)
    opts.target_language = 'English'
    return ActionsEngine.translate_text(opts)
  end,
  ---@param opts? ActionOptions
  summarize_text = function(opts)
    return ActionsEngine.summarize_text(opts)
  end,
  ---@param opts? ActionOptions
  generate_code = function(opts)
    return ActionsEngine.generate_code(opts)
  end,
  ---@param opts? ActionOptions
  start_chat = function(opts)
    return ActionsEngine.start_chat(opts)
  end,
  stop_eval = function()
    return ActionsEngine.stop_eval()
  end,
  show_chat = function()
    return ActionsEngine.show_chat()
  end,
  toggle_chat = function()
    return ActionsEngine.toggle_chat()
  end,
}

return M
