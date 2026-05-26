local Agent = require('fittencode.chat.agent.base')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')

---@class FittenCode.Chat.Agent.RAGAgent
local RAGAgent = setmetatable({}, { __index = Agent })

function RAGAgent.new()
    local self = setmetatable({}, { __index = RAGAgent })
    self:_initialize()
    self.file_content = {}
    self.file_and_directory_names = {}
    self.chunk_contents = {}
    self.chunk_paths = {}
    self.max_length = 32768 * 3
    self.max_results = 300
    self.top_n = 20
    self.workspace_ref_str = ''
    self.local_rag = true
    return self
end

--[[ filedetect ]]

local function is_valid_file(path)
    local ext = path:match('%.([^%.]+)$')
    if not ext then return true end
    local skip = { png = true, jpg = true, jpeg = true, gif = true, ico = true, svg = true,
        pdf = true, zip = true, tar = true, gz = true, rar = true, ['7z'] = true,
        mp3 = true, mp4 = true, wav = true, avi = true, mov = true,
        o = true, obj = true, so = true, dll = true, exe = true, dylib = true,
        pyc = true, class = true,
        lock = true, min = true, map = true,
        ttf = true, woff = true, woff2 = true, eot = true,
    }
    return not skip[ext:lower()]
end

--[[ filescanning ]]

function RAGAgent:get_project_files(max_size)
    self.file_and_directory_names = {}
    self.file_content = {}

    local cwd = vim.fn.getcwd()
    local cmd = 'rg --files --hidden --glob "!.git" 2>nul'
    local raw = vim.fn.systemlist(cmd, cwd)
    if vim.v.shell_error ~= 0 and vim.v.shell_error ~= 1 then
        return { {}, {} }
    end

    local total_size = 0
    for _, p in ipairs(raw) do
        if p ~= '' and is_valid_file(p) then
            local full = cwd .. '/' .. p
            local stat = vim.uv.fs_stat(full)
            if stat and stat.type == 'file' then
                local size = stat.size
                if max_size and total_size + size > max_size then break end
                local f = io.open(full, 'r')
                if f then
                    local content = f:read('*all')
                    f:close()
                    if content then
                        table.insert(self.file_and_directory_names, p)
                        table.insert(self.file_content, content)
                        total_size = total_size + size
                    end
                end
            end
        end
    end

    return { self.file_and_directory_names, self.file_content }
end

--[[ chunking ]]

function RAGAgent:get_chunks()
    self.chunk_contents = {}
    self.chunk_paths = {}
    for i = 1, #self.file_content do
        local content = self.file_content[i]
        local name = self.file_and_directory_names[i]
        if name then
            name = name:match('/(.+)$') or name
        end
        if content and name then
            if #content > 10000 then
                local pos = 1
                while pos <= #content do
                    local end_pos = pos + 9999
                    local nl = content:find('\n', end_pos)
                    if nl then end_pos = nl end
                    if end_pos > #content then end_pos = #content end
                    table.insert(self.chunk_contents, content:sub(pos, end_pos))
                    table.insert(self.chunk_paths, name)
                    pos = end_pos + 1
                end
            elseif #content > 0 then
                table.insert(self.chunk_contents, content)
                table.insert(self.chunk_paths, name)
            end
        end
    end
end

--[[ keyword extraction ]]

local KEYWORD_PROMPT = [[You are a helpful Assistant.
Please summarize the possible keywords for searching in a code project or files based on the user's query, and return the list of keywords in English in JSON format, sorted by importance, with a maximum of 10 keywords.
The keyword should be English. Please make sure that the returned keywords must exist in the code project or files; if they do not exist, then return any 10 that do exist!. You cannot return an empty value.
You must verify that the keywords you propose exist in the file or content. If they are not present, then return any 10 that are present!
Example of the returned result:```json
{"keywords": ["Paris", "celsius", "temperature", "convert", "fahrenheit", "Fahrenheit", "Celsius", "Kelvin", "zero", "call"]}
```
Please only return the JSON result, don't add any other answers!
Each keyword should contain only one word.]]

local TRANSLATE_PROMPT = [[You are a helpful Assistant.
Please translate the user's input into English and maintain the original format.
Example of the returned result:```json
{"keywords": ["Paris", "celsius", "temperature", "convert", "fahrenheit", "Fahrenheit", "Celsius", "Kelvin", "zero", "call"]}
```
Please only return the JSON result, don't add any other answers!]]

function RAGAgent:get_keywords(query, ft_token)
    local r1 = self._call_chat(KEYWORD_PROMPT, query, ft_token)
    if not r1 then return {} end

    local r2 = self._call_chat(TRANSLATE_PROMPT, r1, ft_token)
    if not r2 then return {} end

    local start_pos = r2:find('{')
    local end_pos = r2:reverse():find('}')
    if not start_pos or not end_pos then return {} end
    end_pos = #r2 - end_pos + 1

    local ok, data = pcall(vim.json.decode, r2:sub(start_pos, end_pos))
    if ok and data and data.keywords then
        return data.keywords
    end
    return {}
end

--[[ ripgrep ]]

local function ripgrep_search(keywords, max_results)
    local cwd = vim.fn.getcwd()
    local args = { '--json', '--context', '5', '-i' }
    for _, kw in ipairs(keywords) do
        table.insert(args, '-e')
        table.insert(args, kw)
    end

    local raw = vim.fn.systemlist({ 'rg', unpack(args) }, cwd)
    if vim.v.shell_error ~= 0 then
        return { chunk_paths = {}, chunk_contents = {} }
    end

    local results = {}
    local seen = {}
    for _, line in ipairs(raw) do
        if #results >= max_results then break end
        local ok, data = pcall(vim.json.decode, line)
        if ok and data.type == 'match' then
            local path = data.data.path.text
            local sub = data.data.submatches[1]
            if sub then
                local snippet = data.data.lines.text
                if not seen[path] then
                    seen[path] = true
                    table.insert(results, {
                        path = path,
                        snippet = snippet,
                    })
                end
            end
        end
    end

    local chunk_paths = {}
    local chunk_contents = {}
    for _, r in ipairs(results) do
        table.insert(chunk_paths, r.path)
        table.insert(chunk_contents, r.snippet)
    end
    return { chunk_paths = chunk_paths, chunk_contents = chunk_contents }
end

--[[ scoring ]]

local function score_chunks(chunks, keywords)
    local scores = {}
    for i = 1, #chunks do scores[i] = 0 end

    if #keywords == 0 then
        for i = 1, #chunks do
            if chunks[i] and #chunks[i] > 0 then
                keywords[#keywords + 1] = chunks[i]:sub(1, 1)
            end
        end
    end

    for ki = 1, #keywords do
        local kw = keywords[ki]:lower()
        local weight = (#keywords - ki + 1) / #keywords
        for ci = 1, #chunks do
            if chunks[ci] and chunks[ci]:lower():find(kw, 1, true) then
                scores[ci] = scores[ci] + weight
            end
        end
    end

    return scores
end

local function top_chunks(chunks, paths, scores, top_n)
    local indices = {}
    for i, s in ipairs(scores) do
        if s > 0 then
            indices[#indices + 1] = { score = s, index = i }
        end
    end
    table.sort(indices, function(a, b) return a.score > b.score end)

    local ref = '=====REFERENCES======\n\n'
    for i = 1, math.min(#indices, top_n) do
        local idx = indices[i].index
        local path = paths[idx]:gsub('^./', '')
        local content = chunks[idx]
        ref = ref .. 'path: ' .. path .. '<fitten@refcode>```' .. content .. '```<fitten@refcode>\n\n'
    end
    ref = ref .. '=====RESPONSE======\n\n\n'
    return ref
end

--[[ main RAG methods ]]

function RAGAgent:add_rag_refs(msg, ft_token)
    local _, files = unpack(self:get_project_files(self.max_length))

    local ref = '=====REFERENCES======\n\n'
    for i = 1, #files do
        local name = self.file_and_directory_names[i]
        name = name:match('/(.+)$') or name
        ref = ref .. 'path: ' .. name .. '<fitten@refcode>```' .. files[i] .. '```<fitten@refcode>\n\n'
        if #ref > self.max_length then break end
    end
    ref = ref .. '=====RESPONSE======\n\n\n'

    if #ref < self.max_length then return ref end
    if #self.file_and_directory_names == 0 then return '' end

    local last_user = msg
    last_user = last_user:gsub('@workspace', '')
    last_user = last_user:gsub('@project', '')

    local keywords = self:get_keywords(last_user, ft_token)
    self:get_chunks()

    -- try ripgrep first, fallback to keyword matching
    local rg = ripgrep_search(keywords, self.max_results)
    if #rg.chunk_paths > 0 then
        self.chunk_paths = rg.chunk_paths
        self.chunk_contents = rg.chunk_contents
    end

    local scores = score_chunks(self.chunk_contents, keywords)
    return top_chunks(self.chunk_contents, self.chunk_paths, scores, self.top_n)
end

--[[ agent lifecycle ]]

function RAGAgent:on_chat_start()
    local prompt = self.inputs

    -- Find last <|user|> in prompt
    local last_user_start = nil
    local search_from = 1
    while true do
        local p = prompt:find('<|user|>', search_from, true)
        if not p then break end
        last_user_start = p
        search_from = p + 1
    end

    if not last_user_start then return end

    local last_msg = prompt:sub(last_user_start + 9)
    local is_workspace = last_msg:find('@workspace') ~= nil and self.local_rag
    local is_file = last_msg:find('@file') ~= nil and not is_workspace

    if not is_workspace and not is_file then return end

    local tag = is_workspace and '@workspace' or '@file'
    self:update_state('analyzing project...')

    local ft_token = Client.get_api_key_manager():get_fitten_user_id() or ''
    self.workspace_ref_str = is_file
        and self:add_file_refs(prompt, ft_token)
        or self:add_rag_refs(prompt, ft_token)

    local last_tag_pos = prompt:reverse():find(tag:reverse())
    if last_tag_pos then
        last_tag_pos = #prompt - last_tag_pos + 1
        self.inputs = prompt:sub(1, last_tag_pos - 1) .. self.workspace_ref_str .. prompt:sub(last_tag_pos + #tag)
    end
end

function RAGAgent:add_file_refs(msg, ft_token)
    local last_user = msg
    last_user = last_user:gsub('@file', '')

    -- files are injected via on_chat_start context
    if self._get_files then
        local files = self._get_files()
        if #files > 0 then
            self.chunk_paths = {}
            self.chunk_contents = {}
            for _, f in ipairs(files) do
                local name = f.path
                if name:find('/') then name = name:match('/(.+)$') end
                local content = f.content or ''
                if #content > 0 then
                    if #content > 10000 then
                        local pos = 1
                        while pos <= #content do
                            local ep = pos + 9999
                            local nl = content:find('\n', ep)
                            if nl then ep = nl end
                            if ep > #content then ep = #content end
                            table.insert(self.chunk_contents, content:sub(pos, ep))
                            table.insert(self.chunk_paths, name)
                            pos = ep + 1
                        end
                    else
                        table.insert(self.chunk_contents, content)
                        table.insert(self.chunk_paths, name)
                    end
                end
            end
        end
    end

    local keywords = self:get_keywords(last_user, ft_token)
    local scores = score_chunks(self.chunk_contents, keywords)
    return top_chunks(self.chunk_contents, self.chunk_paths, scores, self.top_n)
end

function RAGAgent:on_chat_message()
    -- filter out references section from render
    if self.message and self.message:find('=====REFERENCES======', 1, true) then
        local ref_start = self.message:find('=====REFERENCES======', 1, true)
        local resp_start = self.message:find('=====RESPONSE======', (ref_start or 1) + 20, true)
        if not resp_start then
            self.message = ''
        end
    end
end

function RAGAgent:on_chat_end()
    if self.workspace_ref_str ~= '' then
        self.message = self.workspace_ref_str .. (self.message or '')
        self.workspace_ref_str = ''
    end
end

return RAGAgent
