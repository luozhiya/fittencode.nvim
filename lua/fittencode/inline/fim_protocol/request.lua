--[[

优化 DIFF 增量数据的计算与传输，考虑以下问题:
- 服务器的缓存机制？同一个文件是否做长期存储，如何失效？
- LSP 是单次服务，BUFFER 的每次修改都被传输
- LSP 增量更新和补全是两个不同的接口，Fitten 服务器则只有一个
- 如果要按照 LSP 的方式，在 nvim_buf_attach on_lines 时需要计算增量数据，并且完成补全存入 Cache 中
- 当触发 TextChangeI 等事件时，查询是否创建了任务，如果有，则等待任务完成，进入Session交互模式

现有问题：
- 当大小超过阈值时，获取的片段在 DIFF 时，字符的边界可能会计算错误？

--]]

local Promise = require('fittencode.base.promise')

local R_base = require('fittencode.inline.fim_protocol.request.base')
local R_diff = require('fittencode.inline.fim_protocol.request.diff')
local R_edit = require('fittencode.inline.fim_protocol.request.edit')
local R_pc = require('fittencode.inline.fim_protocol.request.pc')

local M = {}

---@return FittenCode.Promise<FittenCode.Inline.Prompt>
function M.generate(options)
    local shadow = options.shadow
    local position = options.position
    local uri = options.uri
    local mode = options.mode
    local version = options.version

    ---@type FittenCode.Inline.Prompt.MetaDatas
    ---@diagnostic disable-next-line: missing-fields
    local meta_datas = {}
    return R_base.build(shadow, position, uri):forward(function(base) ---@param base FittenCode.Inline.Prompt.MetaDatas
        meta_datas = vim.tbl_deep_extend('force', meta_datas, base)
        return R_diff.build(base.diff, uri, version)
    end):forward(function(diff) ---@param diff FittenCode.Inline.Prompt.MetaDatas
        meta_datas = vim.tbl_deep_extend('force', meta_datas, diff)
        return R_edit.build(mode)
    end):forward(function(edit) ---@param edit FittenCode.Inline.Prompt.MetaDatas
        meta_datas = vim.tbl_deep_extend('force', meta_datas, edit)
        return R_pc.build(shadow, position, uri)
    end):forward(function(pc) ---@param pc FittenCode.Inline.Prompt.MetaDatas
        meta_datas = vim.tbl_deep_extend('force', meta_datas, pc)
        return Promise.resolved({ inputs = '', meta_datas = meta_datas })
    end)
end

return M
