local Config = require('fittencode.config')

---@class fittencode.Inline
local Inline = {}

---@class fittencode.InlineModel
local model = {}

-- CursorMovedI > ignore(CursorMovedI)
local function triggering_completion(force)
    force = force or false
    -- debounce
end

local function generate_one_stage()
end

local function dismiss_suggestions()
end

local function lazy_completion()
end

function Inline.make_prompt()
end

function Inline.generate_suggestions(completion_data)
end

function Inline.setup()
    vim.api.nvim_create_autocmd({ 'InsertEnter', 'CursorMovedI', 'CompleteChanged' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.hold', { clear = true }),
        pattern = '*',
        callback = function(ev)
            print(string.format('event fired: %s', vim.inspect(ev)))
            triggering_completion(false)
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.hold_bufevent', { clear = true }),
        pattern = '*',
        callback = function()
            if string.match(vim.fn.mode(), '^[iR]') then
                triggering_completion(false)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.dismiss_suggestions', { clear = true }),
        pattern = '*',
        callback = function()
            dismiss_suggestions()
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufLeave' }, {
        group = vim.api.nvim_create_augroup('fittencode.inline.dismiss_suggestions_bufevent', { clear = true }),
        pattern = '*',
        callback = function()
            if string.match(vim.fn.mode(), '^[iR]') then
                dismiss_suggestions()
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'TextChangedI' }, {
        group = vim.api.nvim_create_augroup('fittencode.lazy_completion', { clear = true }),
        pattern = '*',
        callback = function()
            lazy_completion()
        end,
    })
end

return Inline
