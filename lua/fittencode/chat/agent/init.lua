local M = {}

M.Agent = require('fittencode.chat.agent.base')
M.LoopAgent = require('fittencode.chat.agent.loop_agent')
M.RAGAgent = require('fittencode.chat.agent.rag_agent')

function M.build_agents(conv)
    ---@type FittenCode.Chat.Agent[]
    local agents = {}
    table.insert(agents, M.RAGAgent.new())
    table.insert(agents, M.LoopAgent.new())
    return agents
end

return M
