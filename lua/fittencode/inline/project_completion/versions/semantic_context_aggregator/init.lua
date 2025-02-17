-- 对应 VSCode 的 ProjectCompletion

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

-- 全局变量定义
local Me = require('vscode')
local IEcache = {}
local bB = {}
local GE = {}
local QHe = {}
local Uu = {}
local BHe = require('x') -- 需要根据实际模块名进行替换
local _He = 'FittenDocument-FT-ozlpsknq83720108429'
local MAX_CODE_LENGTH = 1e3
local PROMPT_SIZE_LIMIT = 1e4
local MAX_PROMPT_LENGTH = 2e4
local CACHE_VALID_TIME = 1e3 * 60 * 5
local STATS_INTERVAL = 1e3 * 60 * 10
local MAX_CHANGE_LENGTH = 5
local MAX_CACHE_SIZE = 1e6
local BATCH_SIZE = 300
local MAX_SYMBOL_QUERY = 10 * 1e3
local FILE_EXT_TO_LANG = {
    ['py'] = 'python',
    ['ipynb'] = 'python',
    ['h'] = 'c',
    ['c'] = 'c',
    ['cc'] = 'cpp',
    ['cpp'] = 'cpp',
    ['hpp'] = 'cpp',
    ['cxx'] = 'cpp',
    ['C'] = 'cpp',
    ['tcc'] = 'cpp',
    ['inl'] = 'cpp',
    ['txx'] = 'cpp',
    ['cs'] = 'csharp',
    ['csx'] = 'csharp',
    ['kt'] = 'kotlin',
    ['kts'] = 'kotlin',
    ['ktm'] = 'kotlin',
    ['java'] = 'java',
    ['js'] = 'javascript',
    ['ts'] = 'typescript',
    ['php'] = 'php',
    ['go'] = 'go',
    ['rs'] = 'rust',
    ['rb'] = 'ruby',
    ['lua'] = 'lua',
    ['pl'] = 'perl',
    ['pm'] = 'perl',
    ['pm6'] = 'perl',
    ['css'] = 'css',
    ['m'] = 'matlab',
    ['mlx'] = 'matlab'
}
local LANGUAGE_TEMPLATES = {
    ['python'] = { ':', '', '#<content>' },
    ['c'] = { '{', '}', '//<content>' },
    ['cpp'] = { '{', '}', '//<content>' },
    ['csharp'] = { '{', '}', '//<content>' },
    ['kotlin'] = { '{', '}', '//<content>' },
    ['java'] = { '{', '}', '//<content>' },
    ['javascript'] = { '{', '}', '//<content>' },
    ['typescript'] = { '{', '}', '//<content>' },
    ['php'] = { '{', '}', '//<content>' },
    ['go'] = { '{', '}', '//<content>' },
    ['rust'] = { '{', '}', '//<content>' },
    ['ruby'] = { '\n', 'end', '#<content>' },
    ['lua'] = { '\n', 'end', '--<content>' },
    ['perl'] = { '{', '}', '#<content>' },
    ['css'] = { '{', '}', '/*<content>*/' },
    ['matlab'] = { '\n', 'end', '%<content>' },
    ['unknown'] = { '{', '}', '//<content>' }
}
local SCOPE_SYMBOLS = {
    Me.SymbolKind.File,
    Me.SymbolKind.Module,
    Me.SymbolKind.Namespace,
    Me.SymbolKind.Package,
    Me.SymbolKind.Class,
    Me.SymbolKind.Method,
    Me.SymbolKind.Constructor,
    Me.SymbolKind.Enum,
    Me.SymbolKind.Interface,
    Me.SymbolKind.Function,
    Me.SymbolKind.Struct,
    Me.SymbolKind.Operator
}
local LSP_EXTENSIONS = {
    ['python'] = 'ms-python.python',
    ['csharp'] = 'ms-dotnettools.csdevkit',
    ['java'] = 'vscjava.vscode-java-pack',
    ['go'] = 'golang.go',
    ['rust'] = 'rust-lang.rust-analyzer',
    ['php'] = 'DEVSENSE.phptools-vscode',
    ['cpp'] = 'ms-vscode.cpptools-extension-pack',
    ['c'] = 'ms-vscode.cpptools-extension-pack',
    ['dart'] = 'Dart-Code.dart-code'
}
local xHe = { 'plaintext', 'markdown', 'json', 'yaml', 'html', 'css', 'xml' }
local MAX_NOTIFY_TIME = 1e3 * 60 * 60
local lsp_notify_status = {
    ['python'] = { last_notify_time = 0, dismissed_notify = false },
    ['csharp'] = { last_notify_time = 0, dismissed_notify = false },
    ['java'] = { last_notify_time = 0, dismissed_notify = false },
    ['go'] = { last_notify_time = 0, dismissed_notify = false },
    ['rust'] = { last_notify_time = 0, dismissed_notify = false },
    ['php'] = { last_notify_time = 0, dismissed_notify = false },
    ['cpp'] = { last_notify_time = 0, dismissed_notify = false },
    ['c'] = { last_notify_time = 0, dismissed_notify = false },
    ['dart'] = { last_notify_time = 0, dismissed_notify = false }
}
local TEST_CODE_SAMPLES = {
    ['python'] = {
        code = [[
def test():
  print("Hello, world!")

test()
]],
        suffix = 'py'
    },
    ['csharp'] = {
        code = [[
using System;

public class Department
{
    public string Name { get; set; }

    public Department(string name)
    {
        Name = name;
    }
}

class Program
{
    static void Main()
    {
        Department dept = new Department("Engineering");
        Console.WriteLine(dept.Name);
    }
}
]],
        suffix = 'cs'
    },
    ['java'] = {
        code = [[
public class Department {
    private String name;

    public Department(String name) {
        this.name = name;
    }

    public static void main(String[] args) {
        Department dept = new Department("Engineering");
    }
}
]],
        suffix = 'java'
    },
    ['go'] = {
        code = [[
package main

import "fmt"

func main() {
    test()
}

func test() {
    fmt.Println("Hello, world!")
}
]],
        suffix = 'go'
    },
    ['rust'] = {
        code = [[
struct Person {
    name: String,
    age: u32,
}
]],
        suffix = 'rs'
    },
    ['php'] = {
        code = [[
<?php

class Greeting {
    public function sayHello() {
        echo "Hello, world!\n";
    }
}

$greeting = new Greeting();
$greeting->sayHello();
]],
        suffix = 'php'
    },
    ['c'] = {
        code = [[
void test()
{
  return;
}

int main()
{
  test();
  return 0;
}
]],
        suffix = 'c'
    },
    ['cpp'] = {
        code = [[
void test()
{
  return;
}

void main()
{
  test();
}
]],
        suffix = 'cpp'
    },
    ['dart'] = {
        code = [[
void sayHello(String name) {
    print('Hello, $name!');
}

void main() {
    sayHello('World');
}
]],
        suffix = 'dart'
    }
}

-- 定义 FHe 函数
local function FHe(t)
    local e = QHe.tmpdir()
    local r = TEST_CODE_SAMPLES[t].suffix
    local n = TEST_CODE_SAMPLES[t].code
    if not (r and n) then
        return false
    end
    local i = Uu.join(e, 'temp.' .. r)
    local ok = true
    local function err_handler(err)
        print(err)
        ok = false
    end
    local function file_exists(path)
        local f = io.open(path, 'r')
        if f then
            f:close()
            return true
        else
            return false
        end
    end
    -- 模拟异步转同步逻辑
    local file_content = GE.promises.writeFile(i, n)
    local s = Me.workspace.openTextDocument(i)
    local result = Me.commands.executeCommand('vscode.executeDocumentSymbolProvider', s.uri)
    local success = (result and #result > 0) or false
    local function delete_file()
        if file_exists(i) then
            GE.promises.unlink(i)
        end
    end
    if not ok then
        return false
    end
    return success
end

-- 定义 NHe 函数
local function NHe(t)
    local e = t.languageId
    local result = 0
    if e == 'javascript' or e == 'typescript' then
        result = 1
    elseif LSP_EXTENSIONS[e] then
        result = 1 -- 假设 Me.extensions.getExtension 返回非 null
    else
        result = -1
    end
    return result
end

-- 定义 LHe 函数
local function LHe(t)
    if not lsp_notify_status[t] then
        lsp_notify_status[t] = { last_notify_time = 0, dismissed_notify = false }
    end
    local e = lsp_notify_status[t]
    local r = LSP_EXTENSIONS[t]
    local n = '中文翻译接口获取的语言'
    local i = '永不显示'
    local s = '取消'

    if r then
        if e.dismissed_notify or os.time() - e.last_notify_time < MAX_NOTIFY_TIME then
            return
        end
        local o = "Go to 'Extensions' to install"
        e.last_notify_time = os.time()
        Me.window.showInformationMessage(
            'The Language Server for the current language is not installed, so Entire Project Perception based Completion is temporarily unavailable',
            o,
            s
        )
    else
        if xHe[t] then
            return
        end
        -- 其他逻辑省略
    end
end

-- 定义 MHe 函数
local function MHe(t)
    -- 模拟异步逻辑
    local function checkGitIgnore(r)
        local n = Me.workspace.workspaceFolders
        if not n or #n == 0 then
            return false
        end
        local i = n[0].uri.fsPath
        if not i or not string.startswith(r, i) then
            return false
        end
        local s = Uu.join(i, '.gitignore')
        local a = require('ignore').default()
        a.add(GE.promises.readFile(s, 'utf8'))
        local A = Uu.relative(i, r)
        return a.ignores(A)
    end
    if next(IEcache) > MAX_CACHE_SIZE then
        IEcache = {}
    end
    if IEcache[t] then
        return IEcache[t]
    end
    local r = checkGitIgnore(t)
    IEcache[t] = r
    return r
end

-- 定义 PHe 函数
local function PHe(t, e)
    local r = false
    local n = Me.workspace.getConfiguration('fittencode.useProjectCompletion').get('open')
    local i = oM(t)
    local s = 1
    if n == 'Auto' then
        if i >= 1 and e == 1 and s ~= 2 then
            r = true
        end
    elseif n == 'On' then
        if e == 1 and s ~= 2 then
            r = true
        end
    elseif n == 'Off' then
        r = false
    else
        Me.workspace.getConfiguration('fittencode.useProjectCompletion').update('open', nil, Me.ConfigurationTarget.Global)
        if i >= 1 and e == 1 and s ~= 2 then
            r = true
        end
    end
    return r
end

-- 定义 OHe 函数
local function OHe(t, e)
    local r = Me.workspace.workspaceFolders[0].uri.path
    local n = Me.commands.executeCommand('vscode.executeTypeDefinitionProvider', t.uri, e)
    local i = Me.commands.executeCommand('vscode.executeDefinitionProvider', t.uri, e)
    table.insert(n, unpack(i))
    local o = {}
    for _, a in ipairs(n) do
        -- if a instanceof Me.Location then
        --   table.insert(o, a)
        -- elseif a.targetSelectionRange then
        --   table.insert(o, Me.Location(a.targetUri, a.targetSelectionRange))
        -- end
    end
    local results = {}
    for _, a in ipairs(o) do
        if _ie(r, t, a.uri) then
            local A = Me.workspace.openTextDocument(a.uri)
            local c = A.getText(a.range)
            local l = Tie(A, a.range.start)
            local u = rM(c, l, a.uri, a.range.start.line)
            table.insert(results, u)
        end
    end
    return results
end

-- 定义 _ie 函数
local function _ie(t, e, r)
    return string.startswith(r.path, t) and r.path ~= e.uri.path and not MHe(r.fsPath)
end

-- 定义 Rie 函数
local function Rie(t)
    local e = t.uri.fsPath
    local n = t.lineCount
    local i = t.offsetAt(Me.Position(n - 1, 0))
    local s = n .. '_' .. i
    if _S[e] and _S[e] == s then
        return wS[e]
    end
    local function executeSymbolProvider()
        local version = t.version
        for _ = 1, 100 do
            local c = Me.commands.executeCommand('vscode.executeDocumentSymbolProvider', t.uri)
            if t.version == version then
                return c
            end
        end
        return Me.commands.executeCommand('vscode.executeDocumentSymbolProvider', t.uri)
    end
    local i = executeSymbolProvider()
    s = t.lineCount .. '_' .. t.offsetAt(Me.Position(n - 1, 0))
    wS[e] = i
    _S[e] = s
    return i
end

-- 定义 UHe 函数
local function UHe(t)
    local e = string.gsub(t, '.*%.', '')
    return e == '' and 'unknown' or (FILE_EXT_TO_LANG[e] or 'unknown')
end

-- 定义 bie 函数
local function bie(t, e, r, n, i, s, o)
    local a = LANGUAGE_TEMPLATES[s][1]
    local A = Me.Position(e.range.start.line, 0)
    local c = t.offsetAt(A)
    local l = t.offsetAt(e.selectionRange.start)
    local u = t.getText(Me.Range(A, e.range.end_))
    local h = string.find(u, a, l - c + 1)
    if h then
        local E = ''
        if o then
            E = n .. '...\n'
        end
        return string.format('%s%s%s%s\n%s%s', u:sub(1, h), a, '\n', E, r, '\n', i, a)
    else
        return u
    end
end

-- 定义 qHe 函数
local function qHe(t)
    return t:find('\r\n') and '\r\n' or t:find('\n') and '\n' or t:find('\r') and '\r' or '\n'
end

-- 定义 GHe 函数
local function GHe(t)
    local e = 0
    while e <= #t and (string.byte(t, e + 1) == 32 or string.byte(t, e + 1) == 9) do
        e = e + 1
    end
    return string.sub(t, 1, e)
end

-- 定义 Tie 函数
local function Tie(t, e)
    local r = Rie(t)
    local n = UHe(t.fileName)
    local function i(a, A, c)
        local l = ''
        local u = c .. '    '
        for _, h in ipairs(a) do
            if (A or h.selectionRange.start.line == e.line) and SCOPE_SYMBOLS[h.kind] then
                local D = SCOPE_SYMBOLS[h.kind] and { '', u .. '    ' } or { '', u .. '    ' }
                local m = not (A or SCOPE_SYMBOLS[h.kind])
                l = l .. '\n' .. bie(t, h, D[0], D[1], u, n, m)
            elseif t.offsetAt(h.range.end_) - t.offsetAt(h.range.start) > MAX_CODE_LENGTH then
                local D = { '', u .. '    ' }
                l = l .. '\n' .. bie(t, h, D[0], D[1], u, n, true)
            else
                l = l .. '\n' .. u .. t.getText(h.range)
            end
        end
        return { l, u }
    end
    local s = qHe(a)
    local o = string.gsub(a, '%s+', '')
    local a = (r or {})[1]
    if a then
        return o
    else
        return ''
    end
end

-- 定义 xie 函数
local function xie(t, e)
    local function r(A)
        local c = 0
        local l = 0
        local u = #A
        local h = -1
        for d = #A, 1, -1 do
            local E = A:sub(d, d)
            if E == ')' then
                c = c + 1
                if c == 1 and l == 0 then
                    u = d
                end
            elseif E == ']' then
                l = l + 1
                if l == 1 and c == 0 then
                    u = d
                end
            elseif E == '(' then
                c = c - 1
                if c == 0 and l == 0 then
                    h = d
                    break
                end
            elseif E == '[' then
                l = l - 1
                if l == 0 and c == 0 then
                    h = d
                    break
                end
            end
        end
        if h ~= -1 and u ~= -1 then
            return A:sub(1, h - 1) .. A:sub(u + 1)
        else
            return A
        end
    end
    local n = [[([a-zA-Z_]\w*(?:\(.*\)|\[.*\])?)(?:(\.|->|!\.|\?\.)[a-zA-Z_]\w*(?:\(.*\)|\[.*\])?)*|([a-zA-Z_]\w*(?:\(.*\)|\[.*\])?)$]]
    local i = t.getText(e)
    local s = {}
    local a = t.offsetAt(e.start)
    local function add_var(name, position)
        table.insert(s, { name = name, position = position })
    end
    local function process_match(match)
        local c = match[1]
        if c then
            local d = r(c)
            local pos = a + match.index + #d
            add_var(d, t.positionAt(pos))
        end
        local l = { match[2], match[3] }
        for _, group in ipairs(l) do
            if group then
                local D = group:find('(%b())')
                while D do
                    local y = group:sub(D[1], D[2])
                    local I = y:gsub('^%(', ''):gsub('%)$', '')
                    for match_var in I:gfind('[a-zA-Z_]+') do
                        local pos = a + D[1] + match.index + #match_var
                        add_var(match_var, t.positionAt(pos))
                    end
                    D = group:find('(%b())', D[2])
                end
            end
        end
    end
    for match in i:gmatch(n) do
        process_match(match)
    end
    return s
end

-- 定义 oM 函数
local function oM(t)
    local function e(n)
        local i = Me.workspace.getConfiguration('http').get('proxy')
        local s = i and require('vscode-http').ProxyAgent(i) or nil
        local o = require('die').getServerURL()
        local A = Me.extensions.getExtension('FittenTech.Fitten-Code') or Me.extensions.getExtension('FittenTech.Fitten-Code-Enterprise')
        local c = A and A.packageJSON.version or nil
        local response = require('fetch')(o .. '/codeuser/pc_check_auth?user_id=' .. n .. '&ide=vsc&ide_name=vscode&ide_version=' .. Me.version .. '&extension_version=' .. c, {
            method = 'GET',
            headers = { ['Content-Type'] = 'application/json' },
            dispatcher = s
        })
        if response.ok then
            local body = response.text()
            return body == '"yes"' and 1 or 0
        else
            return 0
        end
    end
    local function r(n)
        return e(n)
    end
    if wHe.globalConfig.FITTEN_VERSION ~= 'default' then
        return 2
    end
    if t == XL and (performance.now() - vie) < CACHE_VALID_TIME then
        return bS
    else
        local result = r(t)
        XL = t
        vie = performance.now()
        bS = result
        return result
    end
end

-- 定义 rM 类
local rM = {}
function rM:new()
    local object = {
        name = '',
        compressed_code = '',
        uri = nil,
        query_line = 0
    }
    setmetatable(object, { __index = self })
    return object
end

-- 定义 nM 类
local nM = {}
function nM:new()
    local object = {
        var_key = '',
        prefix = '',
        positions = {},
        source_datas = {},
        status = 0
    }
    setmetatable(object, { __index = self })
    return object
end

function nM:update_source_data(e)
    self.positions = {} -- 模拟异步逻辑
    local s = OHe(e, self.positions[0])
    self.source_datas = s
end

-- 定义 SS 类
local SS = {}
function SS:new()
    local object = {
        children = {},
        vars = {},
        start_line = 0,
        end_line = 0,
        prefix = ''
    }
    setmetatable(object, { __index = self })
    return object
end

-- 定义 iM 类
local iM = {}
function iM:new(e, r, n)
    local object = {
        last_add_code = '',
        start_same_lines = e,
        end_same_lines = r,
        document_uri = n.uri.toString(),
        old_total_lines = n.lineCount
    }
    setmetatable(object, { __index = self })
    return object
end

function iM:sub_update(e, r)
    self.start_same_lines = math.min(self.start_same_lines, e)
    self.end_same_lines = math.min(self.end_same_lines, r)
end

function iM:update(e)
    self.start_same_lines = -1
    self.end_same_lines = -1
    self.old_total_lines = e.lineCount
end

-- 定义 Cd 类
local LastPrompt = {}
function LastPrompt:new(e)
    local object = {
        prompt = '',
        prompt_list = {},
        key_list = {},
        document = e,
        language_keywords = LANGUAGE_TEMPLATES.unknown
    }
    if LANGUAGE_TEMPLATES[e.languageId] then
        object.language_keywords = LANGUAGE_TEMPLATES[e.languageId]
    end
    setmetatable(object, { __index = self })
    return object
end

function LastPrompt:clone()
    local object = LastPrompt:new(self.document)
    object.prompt = self.prompt
    object.prompt_list = self.prompt_list
    object.key_list = self.key_list
    object.language_keywords = self.language_keywords
    return object
end

function LastPrompt:get_key(r)
    return r.uri.toString() .. ':' .. tostring(r.query_line)
end

function LastPrompt:get_prompt()
    return self.prompt
end

function LastPrompt:try_add_prompt(e, r)
    local n = self:get_key(r)
    if vim.tbl_contains(self.key_list, n) then
        return #self.prompt + #r.compressed_code
    end
    local i = ' Below is partical code of ' .. r.uri.toString() .. ' for the variable or function ' .. e.var_key .. ':\n'
    local s = self.language_keywords[2]:gsub('<content>', i) .. r.compressed_code .. '\n\n'
    return #self.prompt + #s
end

function LastPrompt:add_prompt(e, r)
    local n = self:get_key(r)
    if vim.tbl_contains(self.key_list, n) then
        return
    end
    local i = ' Below is partical code of ' .. r.uri.toString() .. ' for the variable or function ' .. e.var_key .. ':\n'
    local s = self.language_keywords[2]:gsub('<content>', i) .. r.compressed_code .. '\n\n'
    self.prompt = self.prompt .. s
    table.insert(self.prompt_list, s)
    table.insert(self.key_list, n)
end

function LastPrompt:add_prompt2(e, r)
    if vim.tbl_contains(self.key_list, e) then
        return
    end
    self.prompt = self.prompt .. r
    table.insert(self.prompt_list, r)
    table.insert(self.key_list, e)
end

-- 定义 DS 类
local ScopeTree = {}

function ScopeTree:new(e)
    local object = {
        root = SS:new(),
        change_state = iM:new(0, 0, e),
        locked = false,
        structure_updated = true,
        last_prompt = LastPrompt:new(e),
        has_lsp = -2
    }
    setmetatable(object, { __index = ScopeTree })
    object:__initialize()
    return object
end

function ScopeTree:__initialize()
    self.handleTextDocumentChange = function(r)
        if r.document.uri.scheme == 'file' and (r.document.fileName:endswith('.gitignore') and (r.document.uri.toString() == self.change_state.document_uri)) then
            for _, n in ipairs(r.contentChanges) do
                local i = Me.Range(
                    r.document.positionAt(n.rangeOffset),
                    r.document.positionAt(n.rangeOffset + #n.text)
                )
                self.change_state.sub_update(i.start.line, r.document.lineCount - i.end_.line - 1)
                self.change_state.last_add_code = n.text
            end
            self:update(r.document)
        end
    end
    -- Me.workspace.onDidChangeTextDocument = object.handleTextDocumentChange
end

function ScopeTree:show_info(msg)
end

local function jHe(t, e, r)
    local n = Me.Position(e, 0)
    local i = Me.Position(r, t.lineAt(r).range.end_.character)
    return t.getText(Me.Range(n, i))
end

function ScopeTree:check_need_update(e)
    if self.change_state.start_same_lines == -1 then
        self:show_info('!! no need update because start_same_lines == -1')
        return false
    end
    local r = self.change_state
    local s = jHe(e, r.start_same_lines, e.lineCount - r.end_same_lines - 1)
    local o = r.old_total_lines - r.start_same_lines - r.end_same_lines
    local a = e.lineCount - r.start_same_lines - r.end_same_lines
    if o > 1 or a > 1 then
        return true
    end
    local A = Me.window.activeTextEditor
    if A and A.document.uri.toString() == e.uri.toString() then
        local c = { '.', '(', '[', '()', '[]', ' ' }
        if vim.tbl_contains(c, self.change_state.last_add_code) then
            return true
        end
    end
    return false
end

function ScopeTree:update(e)
    while self.locked do end
    self.locked = true
    self.structure_updated = false
    if self:check_need_update(e) then
        local r = self:do_update(e)
        self:show_info('======== update completed ==========')
    else
        self:show_info('!! no need update')
    end
    self.locked = false
    self.structure_updated = true
end

function ScopeTree:do_update(e)
    local r = Rie(e)
    local n = self:sync_do_update(e, r)
    self:show_info('structure updated')
    return n
end

function ScopeTree:sync_do_update(e, r)
    local n = self.change_state.old_total_lines
    local i = self:update_tree(e, r, self.change_state.start_same_lines, n - self.change_state.end_same_lines - 1, self.change_state.start_same_lines, e.lineCount - self.change_state.end_same_lines - 1)
    self.change_state:update(e)
    return i
end

function ScopeTree:compare_vars(e, r, n, i)
    local function s(l)
        local u = 0
        if #l.positions == 0 then
            u = 5
        else
            u = 2
        end
        if l.prefix == i then
            local E = false
            for _, m in ipairs(l.positions) do
                if m.line <= n then
                    E = true
                    break
                end
            end
            if E then
                u = 1
            end
        elseif string.startswith(i, l.prefix) then
            u = 3
        else
            u = 4
        end
        local h = 1e7
        local d = 1e7
        for _, E in ipairs(l.positions) do
            local m = math.abs(n - E.line)
            h = math.min(h, m)
            local y = 0
            while y < #i and y < #l.prefix and i:sub(y + 1, y + 1) == l.prefix:sub(y + 1, y + 1) do
                y = y + 1
            end
            d = math.min(d, -y)
        end
        return { u, h, d }
    end
    local o = s(e)
    local a = s(r)
    local A = o[1]
    local c = a[1]
    if A == c then
        if A == 5 then
            return 0
        end
        if A == 1 or A == 2 then
            return o[2] - a[2]
        elseif A == 3 or A == 4 then
            return a[2] - o[2] == 0 and o[2] - a[2] or a[3] - o[3]
        else
            return 0
        end
    else
        return A - c
    end
end

function ScopeTree:update_tree(e, r, n, i, s, o)
    local function a(h, d, E, m, y, A)
        local l = E <= A and m >= A
        local u = string.format('%s%s::', y, h)
        d.start_line = E
        d.end_line = m
        d.prefix = u
        local I = {}
        for _, D in ipairs(h) do
            if vim.tbl_contains(SCOPE_SYMBOLS, D.kind) then
                table.insert(I, D.name)
                if not d.children[D.name] then
                    d.children[D.name] = SS:new()
                end
                a(D.children, d.children[D.name], D.range.start.line, D.range.end_.line, u)
                table.insert(I, D.range)
            end
        end
        for name in pairs(d.children) do
            if not vim.tbl_contains(I, name) then
                d.children[name] = nil
            end
        end
        for name, var in pairs(d.vars) do
            local z = {}
            for _, pos in ipairs(var.positions) do
                if pos.line < n then
                    table.insert(z, Me.Position(pos.line, pos.character))
                elseif pos.line > i then
                    table.insert(z, Me.Position(pos.line - (i - n + 1) + (o - s + 1), pos.character))
                else
                    table.insert(z, pos)
                end
            end
            var.positions = z
        end
        local S = {}
        table.insert(S, Me.Range(Me.Position(m + 1, 0), Me.Position(m + 1, 0)))
        table.sort(S, function(D, V) return D.start.line < V.start.line end)
        local R = E
        for _, D in ipairs(S) do
            local V = D.start.line - 1
            if R <= V then
                local z = xie(e, Me.Range(Me.Position(R, 0), Me.Position(V, e.lineAt(V).range.end_.character)))
                for _, k in ipairs(z) do
                    local ne = k.name
                    local T = k.position
                    if not d.vars[ne] then
                        d.vars[ne] = nM:new()
                        d.vars[ne].var_key = ne
                        d.vars[ne].prefix = u
                        d.vars[ne].positions = {}
                    end
                    table.insert(d.vars[ne].positions, T)
                end
            end
            R = math.max(R, D.end_.line + 1)
        end
        for name in pairs(d.vars) do
            if #d.vars[name].positions == 0 then
                d.vars[name] = nil
            end
        end
        for _, D in pairs(d.vars) do
            table.insert(u, D)
        end
    end
    local A = s
    local c = Me.window.activeTextEditor
    if c and c.document.uri.toString() == e.uri.toString() then
        A = c.selection.active.line
    end
    local l = ''
    local u = {}
    a(r, self.root, 0, e.lineCount - 1, '', A)
    for name in pairs(self.root.vars) do
        table.insert(u, self.root.vars[name])
    end
    table.sort(u, function(m, y) return self:compare_vars(m, y, A, l) end)
    return u
end

function ScopeTree:get_prompt(e, r, n)
    if self.has_lsp ~= 1 then
        return ''
    end
    while self.locked do end
    local o = r
    local a = Me.window.activeTextEditor
    if a and a.document.uri.toString() == e.uri.toString() then
        o = a.selection.active.line
    end
    local l = ''
    local function i(h, d)
        if h.start_line <= o and h.end_line >= o and h.prefix:len() > a:len() then
            a = h.prefix
        end
        for _, y in pairs(h.children) do
            i(y, d)
        end
        for _, y in pairs(h.vars) do
            if y.status == 1 and not vim.tbl_isempty(y.positions) and not vim.tbl_isempty(y.source_datas) then
                table.insert(d, y)
            end
        end
    end
    local A = {}
    i(self.root, A)
    table.sort(A, function(m, y) return self:compare_vars(m, y, o, a) end)
    local c = self.last_prompt:clone()
    local l = LastPrompt:new(e)
    local u = false
    for _, m in ipairs(A) do
        for _, y in ipairs(m.source_datas) do
            local prompt_length = c:try_add_prompt(m, y)
            if prompt_length > PROMPT_SIZE_LIMIT then
                u = true
                break
            end
            c:add_prompt(m, y)
        end
        if u then
            break
        end
    end
    local h = self.last_prompt:clone()
    local d = LastPrompt:new(e)
    for i = #c.prompt_list, 1, -1 do
        h:add_prompt2(c.key_list[i], c.prompt_list[i])
        d:add_prompt2(c.key_list[i], c.prompt_list[i])
    end
    h.prompt = h.prompt or d.prompt
    local E = h:get_prompt()
    self:show_info('============ prompt ================\n' .. E .. '\n=================')
    return E
end
