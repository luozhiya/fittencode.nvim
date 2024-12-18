local Fn = require('fittencode.fn')

local translations = {
    ['Start new chat'] = '开始新对话',
    ['Global completions are activated'] = '全局自动补全功能已激活',
    ['Global completions are deactivated'] = '全局自动补全功能已关闭',
    ['Completions for files with the extensions of {} are disabled'] = '当前文件后缀名：{} 已禁用',
    ['Completions for files with the extensions of {} are enabled, global completions have been automatically activated'] = '当前文件后缀名：{} 已启用, 全局自动补全功能已自动激活',
    ['Completions for the current language are enabled'] = '当前语言自动补全功能已启用',
    ['Enable global completions'] = '启用全局自动补全',
    ['Disable global completions'] = '关闭全局自动补全',
    ['Open Fitten Code settings'] = '打开插件设置',
    ['Open Keyboard Shortcuts'] = '打开快捷键设置',
    ['Select a command'] = '选择一个命令',
    ['Show menu'] = '打开菜单',
    ['Fitten-Code has been updated, click to view update details'] = 'Fitten-Code 已更新，点击查看更新内容',
    ['View Updates'] = '查看更新',
    ['  (Currently no completion options available)'] = '  （当前暂无补全项）',
    ['You can go to the settings interface to customize the unit test framework for a certain language for better generation results'] = '您可以前往设置界面为特定语言指定单元测试框架，以获得更好的生成效果',
    ['Open settings'] = '打开设置',
    ["Go to 'Extensions' to install"] = '前往“扩展”安装',
    ['The Language Server for the current language is not installed, so Entire Project Perception based Completion is temporarily unavailable'] = '当前语言的 Language Server 未安装，项目感知补全暂不可用。',
    ['Never show again'] = '不再显示',
    ['Please install the Language Server for the current language to enable Entire Project Perception based Completion'] = '请安装当前语言的 Language Server，以启用项目感知补全功能',
    ['[Fitten Code] Please login first.'] = '[Fitten Code] 请先登录。',
    ['[Fitten Code] You are already logged in'] = '[Fitten Code] 您已经登录了',
    ['[Fitten Code] Login successful'] = '[Fitten Code] 登录成功',
    ['[Fitten Code] Invalid 3rd-party login source'] = '[Fitten Code] 非法第三方登录源',
    ['[Fitten Code] You are already logged out'] = '[Fitten Code] 您已经登出了',
    ['[Fitten Code] Logout successful'] = '[Fitten Code] 登出成功',
    ['Login'] = '登录',
    ['Dismiss'] = '忽略',
    ['The terminal output is too long, please re-select the text.'] = '终端输出过长，请重新选择文本。',
    ['⚠ Response was cancelled by the user.'] = '⚠ 回复被用户取消。',
    ['Generating commit message'] = '生成提交信息中',
    ["Reply same language as the user's input."] = '请完全使用中文回复',
    ['Please infer and generate the commit message based on these differences.'] = '请根据这些差异推断并生成提交信息。',
    ['Please note that the submission information should be succinct, and if there are more changes, please summarize them.'] = '请注意，提交信息应简洁明了，如果有更多修改，请总结这些修改。',
    ['Answer only the content of the information to be submitted, do not provide additional answers.'] = '请只回复提交信息的内容，不要提供额外的回答。',
    ['When generating the submission information, pay more attention to the changes in the content of the file, and please do not describe changes to the file itself in your answer, such as modifications to a file, changes to the file name, etc. Do not mention them.'] =
    '在生成提交信息时，更关注文件内容的变化，请不要在回答中描述文件自身的变化，例如修改了哪个文件、文件名更改等。不要提及这些。',
    ['Network response was not ok.'] = '网络响应超时。',
    ['No Git repository found.'] = '没有找到 Git 仓库。',
    ['No modification information found in the temporary.'] = '没有发现暂存中的修改。',
    ['Enable completions for files with the extensions of {}'] = '启用对 .{} 文件的自动补全',
    ['Disable completions for files with the extensions of {}'] = '关闭对 .{} 文件的自动补全'
}

local function translate(key, ...)
    local lang = Fn.display_preference()
    local v = key
    if Fn.startwith(lang, 'zh') then
        v = translations[key] or key
    end
    return Fn.format(v, ...)
end

return translate
