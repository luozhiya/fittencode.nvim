local Editor = require('fittencode.editor')
local Document = require('fittencode.inline.product_completion.v1.document')

local LastPrompt = {}
LastPrompt.__index = LastPrompt

local file_delimiters = {
    python = { ':', '', '#<content>' },
    c = { '{', '}', '//<content>' },
    cpp = { '{', '}', '//<content>' },
    csharp = { '{', '}', '//<content>' },
    kotlin = { '{', '}', '//<content>' },
    java = { '{', '}', '//<content>' },
    javascript = { '{', '}', '//<content>' },
    typescript = { '{', '}', '//<content>' },
    php = { '{', '}', '//<content>' },
    go = { '{', '}', '//<content>' },
    rust = { '{', '}', '//<content>' },
    ruby = { '\n', 'end', '#<content>' },
    lua = { '\n', 'end', '--<content>' },
    perl = { '{', '}', '#<content>' },
    css = { '{', '}', '/*<content>*/' },
    matlab = { '\n', 'end', '%<content>' },
    unknown = { '{', '}', '//<content>' }
}

function LastPrompt:new(document)
    local instance = setmetatable({}, LastPrompt)
    instance.prompt = ''
    instance.prompt_list = {}
    instance.key_list = {}
    instance.language_keywords = {}
    instance.document = document
    instance.language_keywords = file_delimiters.unknown
    if file_delimiters[document.language_id] then
        instance.language_keywords = file_delimiters[document.language_id]
    end
    return instance
end

function LastPrompt:clone()
    local lp = LastPrompt:new(self.document)
    lp.prompt = self.prompt
    lp.prompt_list = { table.unpack(self.prompt_list) }
    lp.key_list = { table.unpack(self.key_list) }
    lp.language_keywords = { table.unpack(self.language_keywords) }
    return lp
end

function LastPrompt:get_key(e)
    return e.uri .. ':' .. e.query_line
end

function LastPrompt:get_prompt()
    return self.prompt
end

function LastPrompt:try_add_prompt(e, r)
    local n = self:get_key(r)
    if vim.tbl_contains(self.key_list, n) then
        return #self.prompt
    end
    local i = ' Below is partical code of ' .. (r.uri and r.uri or '') .. ' for the variable or function ' .. e.var_key .. ':\n'
    local s = self.language_keywords[3]:gsub('<content>', i) .. r.compressed_code .. '\n'
    return #self.prompt + #s
end

function LastPrompt:add_prompt(e, r)
    local key = self:get_key(r)
    if vim.tbl_contains(self.key_list, key) then
        return
    end
    local i = ' Below is partical code of ' .. (r.uri and r.uri or '') .. ' for the variable or function ' .. e.var_key .. ':\n'
    local prompt = self.language_keywords[3]:gsub('<content>', i) .. r.compressed_code .. '\n'
    self.prompt = self.prompt .. prompt
    table.insert(self.prompt_list, prompt)
    table.insert(self.key_list, key)
end

function LastPrompt:add_prompt2(key, prompt)
    if not vim.tbl_contains(self.key_list, key) then
        self.prompt = self.prompt .. prompt
        table.insert(self.prompt_list, prompt)
        table.insert(self.key_list, key)
    end
end

return LastPrompt
