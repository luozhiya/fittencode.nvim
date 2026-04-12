local Promise = require('fittencode.fn.promise')
local Process = require('fittencode.fn.process')
local Log = require('fittencode.log')

local M = {}

---@class FittenCode.Fn.GitPatchOptions
---@field output? string [optional] 输出的 patch 文件路径，若未指定则返回内容字符串

---@class FittenCode.Fn.GitPatchResult
---@field patch_content string

--- 根据当前 stage 生成 patch
---@param options? FittenCode.Fn.GitPatchOptions
---@return FittenCode.Promise<FittenCode.Fn.GitPatchResult>
function M.generate_patch(options)
    options = options or {}
    return Promise.new(function(resolve, reject)
        local args = { 'diff', '--cached', '-z' }
        local p = Process.new('git', args, {})
        local output = {}
        local errors = {}

        p:on('stdout', function(data) table.insert(output, data) end)
        p:on('stderr', function(data) table.insert(errors, data) end)
        p:on('error', reject)

        p:on('exit', function(code)
            if code ~= 0 then
                return reject({
                    _msg = table.concat(errors, '\n'),
                    _metadata = { exit_code = code }
                })
            end
            local patch_content = table.concat(output, '')
            if options.output then
                local file, err = io.open(options.output, 'w')
                if not file then
                    return reject({
                        _msg = 'Failed to write patch file: ' .. (err or 'unknown error')
                    })
                end
                file:write(patch_content)
                file:close()
            end
            resolve({ patch_content = patch_content })
        end)

        p:async()
    end)
end

---@class FittenCode.Fn.GitRepoRootResult
---@field root_path string 仓库根目录的绝对路径（末尾无 '/'）

--- 获取当前 Git 仓库的根目录绝对路径
---@return FittenCode.Promise<FittenCode.Fn.GitRepoRootResult>
function M.get_repo_root()
    return Promise.new(function(resolve, reject)
        local args = { 'rev-parse', '--show-toplevel' }
        local p = Process.new('git', args, {})
        local output = {}
        local errors = {}

        p:on('stdout', function(data) table.insert(output, data) end)
        p:on('stderr', function(data) table.insert(errors, data) end)
        p:on('error', reject)

        p:on('exit', function(code)
            if code ~= 0 then
                return reject({
                    _msg = 'Failed to get repository root: ' .. table.concat(errors, '\n'),
                    _metadata = { exit_code = code }
                })
            end
            local root = table.concat(output, ''):gsub('\n$', '')
            resolve({ root_path = root })
        end)

        p:async()
    end)
end

---@class FittenCode.Fn.GitStagedPathsOptions
---@field absolute? boolean [optional] 是否返回绝对路径，默认为 true

---@class FittenCode.Fn.GitStagedPathsResult
---@field paths string[] 暂存区修改的文件路径列表

--- 根据当前的 stage 获取修改文件的路径（默认返回绝对路径）
---@param options? FittenCode.Fn.GitStagedPathsOptions
---@return FittenCode.Promise<FittenCode.Fn.GitStagedPathsResult>
function M.get_staged_file_paths(options)
    options = options or {}
    return Promise.new(function(resolve, reject)
        local args = { 'diff', '--cached', '--name-only' }
        local p = Process.new('git', args, {})
        local output = {}
        local errors = {}

        p:on('stdout', function(data) table.insert(output, data) end)
        p:on('stderr', function(data) table.insert(errors, data) end)
        p:on('error', reject)

        p:on('exit', function(code)
            if code ~= 0 then
                return reject({
                    _msg = table.concat(errors, '\n'),
                    _metadata = { exit_code = code }
                })
            end

            -- 将输出按行分割，过滤空行
            local raw = table.concat(output, '')
            local paths = {}
            for line in raw:gmatch('[^\r\n]+') do
                if line ~= '' then
                    table.insert(paths, line)
                end
            end

            -- 如果只需要相对路径，直接返回
            if options.absolute == false then
                return resolve({ paths = paths })
            end

            -- 获取仓库根目录并将相对路径转换为绝对路径
            M.get_repo_root():forward(function(root_result)
                local root = root_result.root_path
                local abs_paths = {}
                for _, rel in ipairs(paths) do
                    table.insert(abs_paths, root .. '/' .. rel)
                end
                resolve({ paths = paths, abs_paths = abs_paths })
            end):catch(reject)
        end)

        p:async()
    end)
end

---@class FittenCode.Fn.GitLogOptions
---@field oneline? boolean [optional] 是否使用一行简洁格式，默认为 false（多行详细格式）
---@field count? number [optional] 显示的提交数量，例如 10，默认不限

---@class FittenCode.Fn.GitLogResult
---@field log_output string

--- 获取当前分支的提交日志（支持一行或多行格式）
---@param options? FittenCode.Fn.GitLogOptions
---@return FittenCode.Promise<FittenCode.Fn.GitLogResult>
function M.get_log(options)
    options = options or {}
    return Promise.new(function(resolve, reject)
        local args = { 'log' }
        if options.oneline then
            table.insert(args, '--oneline')
        end
        if options.count and options.count > 0 then
            table.insert(args, '-' .. tostring(options.count))
        end

        local p = Process.new('git', args, {})
        local output = {}
        local errors = {}

        p:on('stdout', function(data) table.insert(output, data) end)
        p:on('stderr', function(data) table.insert(errors, data) end)
        p:on('error', reject)

        p:on('exit', function(code)
            if code ~= 0 then
                return reject({
                    _msg = table.concat(errors, '\n'),
                    _metadata = { exit_code = code }
                })
            end
            resolve({ log_output = table.concat(output, '') })
        end)

        p:async()
    end)
end

---@class FittenCode.Fn.GitHunk
---@field old_start number 旧文件起始行号
---@field old_count number 旧文件受影响行数（若为0表示新增）
---@field new_start number 新文件起始行号
---@field new_count number 新文件受影响行数（若为0表示删除）

---@class FittenCode.Fn.GitFileHunks
---@field file string 文件路径（相对路径，来自 diff 输出中的 +++ b/...）
---@field hunks FittenCode.Fn.GitHunk[] 该文件包含的所有 hunk 信息

--- 解析 Git diff 输出，提取每个文件的 hunk 信息（相对路径与行范围）
--- 适用于 unified diff 格式（如 git diff、git diff --cached 的输出）
---@param diff_output string 完整的 `git diff` 输出内容
---@return FittenCode.Fn.GitFileHunks[] 每个有修改的文件及其 hunk 列表
function M.parse_diff_hunks(diff_output)
    local files = {}

    -- 按文件分割 diff（每个文件以 "diff --git" 开头）
    for file_block in diff_output:gmatch('diff %-%-git[^\n]-\n(.-)(?=diff %-%-git|$)') do
        -- 提取新文件路径（通常在 +++ b/ 之后）
        local new_file = file_block:match('^%+%+%+ b/([^\n]+)')
        if new_file then
            local file_hunks = { file = new_file, hunks = {} }

            -- 匹配所有 hunk 头信息
            for old_start, old_count, new_start, new_count in file_block:gmatch('@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@') do
                local hunk = {
                    old_start = tonumber(old_start),
                    old_count = old_count ~= '' and tonumber(old_count) or 1,
                    new_start = tonumber(new_start),
                    new_count = new_count ~= '' and tonumber(new_count) or 1,
                }
                table.insert(file_hunks.hunks, hunk)
            end

            -- 只添加至少有一个 hunk 的文件
            if #file_hunks.hunks > 0 then
                table.insert(files, file_hunks)
            end
        end
    end

    return files
end

return M
