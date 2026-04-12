local Config = require('fittencode.config')
local CommitMessage = require('fittencode.generators.commit_message')
local F = require('fittencode.fn.buf')
local Promise = require('fittencode.fn.promise')
local Git = require('fittencode.fn.git')
local Context = require('fittencode.inline.fim_protocol.context')
local Position = require('fittencode.fn.position')
local ProjectInsight = require('fittencode.pi')
local Log = require('fittencode.log')

local M = {}

local pre_request = nil
local trigger_buf = nil

local function is_commit_editmsg(buf)
    local name = F.filename(buf)
    return vim.endswith(name, 'COMMIT_EDITMSG')
end

local function generate_patch()
    return Git.generate_patch()
end

local function get_log()
    return Git.get_log({ count = 3 })
end

local function get_staged_file_paths()
    return Git.get_staged_file_paths({ absolute = true }):forward(function(_)
        local uris = vim.tbl_map(function(path)
            return vim.uri_from_fname(path)
        end, _.abs_paths)
        return { abs_paths = _.abs_paths, uris = uris }
    end)
end

local function get_lsp_ctx(uris)
    local promises = {}
    vim.tbl_map(function(uri)
        promises[#promises + 1] = ProjectInsight.request(uri)
    end, uris)
    return Promise.all(promises):catch(function() return Promise.resolved({}) end)
end

local function get_source_fragments(uri, range)
    local buf = vim.uri_to_bufnr(uri)
    if not vim.api.nvim_buf_is_loaded(buf) then
        vim.fn.bufload(buf)
    end
    local pos = Position.of(range.start + range.count / 2, 0)
    local fragments = Context.retrieve_context_fragments(buf, pos, 100)
    return fragments.prefix .. fragments.suffix
end

local function stringfiy_sourcefragments(uris, sourcefragments)
    local result = {}
    for i, uri in ipairs(uris) do
        result[#result + 1] = '### URI(hunk source fragments) ' .. uri
        for j, fragment in ipairs(sourcefragments[i] or {}) do
            result[#result + 1] = '```'
            result[#result + 1] = fragment
            result[#result + 1] = '```'
        end
    end
    return table.concat(result, '\n')
end

local function stringfiy_context(content)
    local result = {}
    for i, item in ipairs(content) do
        result[#result + 1] = ProjectInsight.stringfy_general(item.context, item.dependencies, item.uri, 2)
    end
    return table.concat(result, '\n')
end

local function generate_options()
    return Promise.all({
        generate_patch(),
        get_log(),
        get_staged_file_paths() }):forward(function(_)
        local patch = _[1].patch_content
        Log.debug('Patch: {}', patch)
        local log = _[2].log_output
        Log.debug('Log: {}', log)
        local abs_paths = _[3].abs_paths
        Log.debug('Staged file paths: {}', abs_paths)
        local uris = _[3].uris
        local files_with_hunks = Git.parse_diff_hunks(patch)
        Log.debug('Files with hunks: {}', files_with_hunks)
        local sourcefragments = {}
        for i, file in ipairs(files_with_hunks) do
            local subfrags = {}
            for j, hunk in ipairs(file.hunks) do
                subfrags[#subfrags + 1] = get_source_fragments(uris[i], { start = hunk.new_start, count = hunk.new_count })
            end
            sourcefragments[i] = subfrags
        end
        return get_lsp_ctx(uris):forward(function(content)
            return { patch = patch, log = log, abs_paths = abs_paths, sourcefragments = stringfiy_sourcefragments(uris, sourcefragments), content = content }
        end)
    end):forward(function(_)
        return Promise.resolved({
            options = {
                language = Config.language_preference.commit_message_preference,
                type = Config.add_type_to_commit_message.open,
                patch = _.patch,
                log = _.log,
                content = stringfiy_context(_.content),
                sourcefragments = _.sourcefragments,
            }
        })
    end):catch(function(err)
        Log.error('Error generating commit message options: {}', err)
    end)
end

function M.setup()
    vim.keymap.set('i', '<A-g>', function()
        if pre_request then
            pre_request:abort()
            pre_request = nil
        end
        local buf = vim.api.nvim_get_current_buf()
        if not is_commit_editmsg(buf) then
            return
        end
        generate_options():forward(function(options)
            Log.debug('Commit message options: {}', options)
            local p, request = CommitMessage.commit_message(options)
            if not request then
                return Promise.rejected()
            end
            trigger_buf = buf
            pre_request = request

            p:forward(function(result)
                Log.debug('Commit message result: {}', result)

                if not vim.api.nvim_buf_is_valid(trigger_buf) then
                    return Promise.rejected()
                end
                if vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()) ~= trigger_buf then
                    return Promise.rejected()
                end
                -- Insert the commit message
                vim.api.nvim_buf_set_lines(trigger_buf, 0, 1, false, { result })
            end)
        end)
    end, { desc = 'Generate commit message' })
end

return M
