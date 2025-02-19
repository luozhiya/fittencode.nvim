-- 对应 VSCode 的 ProjectCompletionOld 类

--[[
ProjectCompletionOld 类生成 prompt 的核心逻辑如下：

1. **文档监听与结构维护**
   - 通过 DS 类监听文档变化（onDidChangeTextDocument），维护一个树状符号结构（ScopeTree）
   - 树节点包含变量信息和子作用域，通过解析 DocumentSymbol 构建层次结构

2. **变量收集策略**
   - 遍历符号树收集满足以下条件的变量：
     - 状态为 1（已成功更新）
     - 位于当前光标所在行附近的上下文作用域
     - 前缀匹配当前代码位置的符号层级（如 obj.method 的层级）

3. **代码压缩与格式化**
   - 使用 Tie() 函数压缩符号代码：
     * 保留关键结构（类/函数定义）
     * 折叠深层嵌套代码为"..."
     * 去除空行和冗余缩进
   - 用语言对应的注释语法包裹代码块（如 Python 用 # 注释）

4. **智能拼接策略**
   - 优先级排序：最近使用 > 作用域距离 > 前缀匹配度
   - 动态长度控制（vHe=1000, SHe=2000）：
     * 尝试添加时检查总长度
     * 超过阈值时停止添加新内容
   - 增量更新机制：保留上次有效的 prompt 片段，避免重复计算

5. **多源数据整合**
   - 通过 executeDefinitionProvider 获取跨文件定义
   - 过滤被 .gitignore 忽略的文件路径
   - 合并当前文件和外部引用的符号信息
--]]

-- 输出示例：
--[[
# Below is partical code of file:///src/user.py for the variable or function User::getName:
class User:
    def getName(self):  # Returns formatted user name
        ...
        return f"{self.last}, {self.first}"

# Below is partical code of file:///src/db/dao.py for the variable or function UserDAO::find_by_id:
class UserDAO:
    def find_by_id(self, uid):  # Core query method
        with self.conn.cursor() as cur:
            cur.execute("SELECT * FROM users WHERE id=%s", (uid,))
            ...
--]]

local ProjectCompletionImpl = require('fittencode.inline.project_completion.versions.tree_based_completion.project_completion')

local TreeBasedCompletion = {}
TreeBasedCompletion.__index = TreeBasedCompletion

function TreeBasedCompletion.new()
    local obj = setmetatable({}, TreeBasedCompletion)
    obj:__initialize()
    return obj
end

function TreeBasedCompletion:__initialize()
    self.impl = ProjectCompletionImpl:new()
end

function TreeBasedCompletion:generate_prompt(uri, position)
    return self.impl:get_prompt(uri, position)
end

return TreeBasedCompletion
