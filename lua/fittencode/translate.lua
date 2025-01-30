local Fn = require('fittencode.fn')
local Language = require('fittencode.language')

local translations = {
    ['  (Currently no completion options available)'] = '  （当前暂无补全项）',
    ['(Contact customer service for invitation code)'] = '（联系客服获取邀请码）：',
    ['[Fitten Code] Invalid 3rd-party login source'] = '[Fitten Code] 无效第三方登录源',
    ['[Fitten Code] Login successful'] = '[Fitten Code] 登录成功',
    ['[Fitten Code] Logout successful'] = '[Fitten Code] 登出成功',
    ['[Fitten Code] Please login first.'] = '[Fitten Code] 请先登录。',
    ['[Fitten Code] You are already logged in'] = '[Fitten Code] 您已经登录了',
    ['[Fitten Code] You are already logged out'] = '[Fitten Code] 您已经登出了',
    ['[Free Public Beta] Fitten Code Pro is a powerful model with high accuracy, supports online search, and can solve more challenging problems. This model consumes more resources, and it is recommended to use Fitten Code Fast first, and if it cannot solve the problem, consider using Fitten Code Pro Search.'] = '[免费公测中] Fitten Code Pro 是一个更强大的模型，准确率高，支持联网搜索，可以解决更难的问题。此模型资源消耗较大，建议优先使用 Fitten Code Fast，如果无法解决问题，再考虑使用 Fitten Code Pro Search。',
    ['[Free Public Beta] High accuracy, supports online search, and can solve more challenging problems.'] = '[公测中] 准确率高，支持联网搜索，可以解决更难的问题',
    ['* Scanning this QR code indicates my agreement to the '] = '* 扫描此二维码代表您已同意',
    ['⚠ Response was cancelled by the user.'] = '⚠ 回复被用户取消。',
    ['Add comments'] = '添加注释',
    ['Add instructions...'] = '添加指示...',
    ['Add New Phrase(Title:Phrase)'] = '添加新常用语（标题:常用语）',
    ['All your conversations will be deleted and you will not be able to retrieve them.'] = '所有对话将被删除且无法恢复。',
    ['Already have an account'] = '已有账号',
    ['Answer only the content of the information to be submitted, do not provide additional answers.'] = '请只回复提交信息的内容，不要提供额外的回答。',
    ['Are you sure you want to delete all conversations?'] = '确定要删除所有对话吗？',
    ['Ask for knowledge base'] = '对知识库进行提问',
    ['Ask Question'] = '提交反馈',
    ['Ask...'] = '进行询问...',
    ['Back to Logging In with Password'] = '返回密码登录',
    ['Back to Logging In'] = '返回登录',
    ['Back to Signing Up with Password'] = '返回密码注册',
    ['Back'] = '返回',
    ['Break down and explain the following code in detail step by step, then summarize the code (emphasize its main function).'] = '逐步分解并详细解释以下代码，然后总结代码（强调其主要功能）。',
    ['Can the structure of this code be improved? Please provide suggestions for refactoring.'] = '这段代码的结构可以改进吗？请提供重构建议。',
    ['Cancel'] = '关闭',
    ['Click to remove'] = '点击删除',
    ['Collapse workspace reference'] = '收起 workspace 参考',
    ['Common Phrases'] = '常用语',
    ['Completions for files with the extensions of {} are disabled'] = '当前文件后缀名：{} 已禁用',
    ['Completions for files with the extensions of {} are enabled'] = '当前文件后缀名：{} 已启用',
    ['Completions for files with the extensions of {} are enabled, global completions have been automatically activated'] = '当前文件后缀名：{} 已启用, 全局自动补全功能已自动激活',
    ['Completions for the current language are enabled'] = '当前语言自动补全功能已启用',
    ['Confirm Password'] = '确认密码',
    ['Confirm'] = '确认',
    ['Copy Share Link'] = '复制分享链接',
    ['Could this code be further simplified? Please give your suggestions.'] = '这段代码是否可以进一步简化？请给出建议。',
    ['Delete All Conversations'] = '删除所有对话',
    ['Delete conversation'] = '删除对话',
    ['Delete'] = '删除',
    ['Describe the image and reproduce it through a single HTML.'] = '描述图片并通过单个HTML再现。',
    ['Description:'] = '描述:',
    ['Diagnose Error'] = '诊断错误',
    ['Disable completions for files with the extensions of {}'] = '关闭对 .{} 文件的自动补全',
    ['Disable global completions'] = '关闭全局自动补全',
    ['Dismiss'] = '忽略',
    ['Document Code'] = '生成注释',
    ['Edit Code'] = '编辑代码',
    ['Edit Phrase Title'] = '编辑常用语标题',
    ['Edit'] = '编辑',
    ['Email'] = '邮箱',
    ['Enable completions for files with the extensions of {}'] = '启用对 .{} 文件的自动补全',
    ['Enable global completions'] = '启用全局自动补全',
    ['Enhance code readability'] = '增强代码可读性',
    ['Enter instructions...'] = '输入指令...',
    ['Enter the description of the knowledge base'] = '请输入知识库描述',
    ['Enter the name of the knowledge base'] = '请输入知识库名称',
    ['Expand workspace reference'] = '展开 workspace 参考',
    ['Explain Code'] = '解释代码',
    ['Explain this code.'] = '解释此代码。',
    ['Export conversation'] = '导出对话',
    ['Failed to login. Please check your network.'] = '无法登录，请检查网络。',
    ['Fast, and easy to use for daily use.'] = '速度快，适合日常使用',
    ['File format error, only non-binary files and zip files are supported'] = '文件格式错误，仅支持非二进制文件和zip文件',
    ['Find Bugs'] = '查找Bug',
    ['Fitten-Code has been updated, click to view update details'] = 'Fitten-Code 已更新，点击查看更新内容',
    ['Fix syntax errors'] = '修复语法错误',
    ['Fold'] = '折叠窗口',
    ['Forgot Password'] = '忘记密码',
    ['Generate a Red-Black Tree in C++'] = '用C++生成红黑树',
    ['Generate Code'] = '生成代码',
    ['Generate Unit Test'] = '生成单元测试',
    ['Generate'] = '生成',
    ['Generating commit message'] = '生成提交信息中',
    ['Generating'] = '生成中',
    ['Global completions are activated'] = '全局自动补全功能已激活',
    ['Global completions are deactivated'] = '全局自动补全功能已关闭',
    ['Hide banner'] = '隐藏此提示',
    ['How to learn python programming?'] = '如何学习Python编程？',
    ['I agree to the'] = '我同意',
    ['Implement a Snake game using a single HTML.'] = '使用单个HTML实现贪吃蛇游戏。',
    ['Implement quicksort algorithm in Python'] = '用Python实现快速排序算法',
    ['Improve code style'] = '改善代码风格',
    ['Invalid invitation code, please try again.'] = '邀请码错误，请重新输入',
    ['Invalid phone number'] = '手机号无效',
    ['Knowledge base name'] = '知识库名称',
    ['Knowledge Base'] = '共享知识库',
    ['Last update time:'] = '更新时间:',
    ['Learn More'] = '使用教程',
    ['Local Files Count:'] = '本地文件数量:',
    ['Log in / Sign up with third party'] = '使用第三方账号登录/注册',
    ['Log In'] = '登录',
    ['Logging in...'] = '登录中...',
    ['Login'] = '登录',
    ['Logout'] = '登出',
    ['Network response was not ok.'] = '网络响应超时。',
    ['Never show again'] = '不再显示',
    ['New Chat'] = '新的对话',
    ['New Enterprise Shared Knowledge Base'] = '新增企业共享知识库',
    ['New knowledge base'] = '新建知识库',
    ['New Password'] = '新密码',
    ['New Phrase'] = '新常用语',
    ['No Git repository found.'] = '没有找到 Git 仓库。',
    ['No modification information found in the temporary.'] = '没有发现暂存中的修改。',
    ['OK'] = '确定',
    ['Only consider defects that would lead to erroneous behavior.'] = '只考虑会导致错误行为的缺陷。',
    ['Open Fitten Code settings'] = '打开插件设置',
    ['Open Keyboard Shortcuts'] = '打开快捷键设置',
    ['Open settings'] = '打开设置',
    ['Optimize code'] = '优化代码',
    ['Or log in / sign up with'] = '其他登录/注册方式',
    ['Or sign up with'] = '其他注册方式',
    ['Password not match'] = '密码不匹配',
    ['Password: '] = '密码：',
    ['Password'] = '密码',
    ['Phone Number'] = '手机号码',
    ['Phone'] = '手机',
    ['PhoneNumber'] = '手机号',
    ['Please edit the code according to the following requirements:'] = '请根据以下要求编辑代码：',
    ['Please enter the invitation code to apply for free use.'] = '请输入邀请码以申请免费使用',
    ['Please enter the invitation code...'] = '请输入邀请码...',
    ['Please explain the reason for the error and provide possible solutions.'] = '请解释错误原因并提供可能的解决方案。',
    ['Please infer and generate the commit message based on these differences.'] = '请根据这些差异推断并生成提交信息。',
    ['please input all info'] = '请输入全部信息',
    ['please input username and password'] = '请输入用户名和密码',
    ['Please install the Language Server for the current language to enable Entire Project Perception based Completion'] = '请安装当前语言的 Language Server，以启用项目感知补全功能',
    ['Please note that the submission information should be succinct, and if there are more changes, please summarize them.'] = '请注意，提交信息应简洁明了，如果有更多修改，请总结这些修改。',
    ['Please select text first.'] = '请先选择文本。',
    ['Press Enter to save'] = '按Enter键保存',
    ['Privacy Policy'] = '隐私政策',
    ['Refactor Code'] = '重构代码',
    ['Reference'] = '引用信息',
    ['Regenerate response'] = '重新生成回复',
    ['Regenerate'] = '重新生成',
    ['Register'] = '注册',
    ['Reply...'] = '进行回复...',
    ['Reset Password'] = '修改密码',
    ['Reverse'] = '反序',
    ['Select a command'] = '选择一个命令',
    ['Send'] = '发送',
    ['Share'] = '分享',
    ['Show menu'] = '打开菜单',
    ['Sign up with third party'] = '使用第三方账号注册',
    ['Sign Up'] = '注册',
    ['Simplify Code'] = '简化代码',
    ['Someone shared a code snippet with you'] = '有人分享了一个代码片段给你',
    ['Start new chat'] = '开始新对话',
    ['Successfully reset password'] = '密码修改成功',
    ['Successfully sent code'] = '代码发送成功',
    ['Successfully signed up!'] = '注册成功！',
    ['Terminal Analyse'] = '终端分析',
    ['The above code is optimized to reduce unnecessary calculations, remove redundant code, and add appropriate error handling mechanisms.'] = '对以上代码进行优化，减少不必要的计算，去除冗余代码，并增加适当的错误处理机制。',
    ['The code that needs to be edited is as follows, please maintain the indentation format of this code:'] = '需要编辑的代码如下，请保持该代码的缩进格式：',
    ['The code that needs to be optimized is as follows, please keep the syntax type of the code unchanged.'] = '需要优化的代码如下，请保持代码的语法格式不变。',
    ['The error message is: '] = '报错信息为：',
    ['The following code is selected by the user, which may be mentioned in the subsequent conversation:'] = '下面代码由用户选择，可能在后续对话中提及：',
    ['The Language Server for the current language is not installed, so Entire Project Perception based Completion is temporarily unavailable'] = '当前语言的 Language Server 未安装，项目感知补全暂不可用。',
    ['The problematic code is: '] = '报错代码为：',
    ['The surrounding code is: '] = '报错代码上下文为：',
    ['The terminal output is too long, please re-select the text.'] = '终端输出过长，请重新选择文本。',
    ['Try In Browser'] = '在浏览器中试用',
    ['Understand, you can continue to enter your problem.'] = '理解了，您可以继续输入您的问题。',
    ['Understood, you can continue to enter your question.'] = '理解了，您可以继续输入您的问题。',
    ['Upload file'] = '上传文件',
    ['Uploading file, please wait...'] = '文件上传中，请等待上传完成再进行其他操作',
    ['Use Fitten Code in the text editor to get the best programming experience'] = '在文本编辑器中使用 Fitten Code 以获得最佳编程体验',
    ['User Agreement'] = '用户协议',
    ['User Center'] = '用户中心',
    ['User Guide'] = '用户指南',
    ['User'] = '用户名',
    ['Username or phoneNumber'] = '用户名或手机号',
    ['Username'] = '用户名',
    ['Username/Email/Phone(+CountryCode): '] = '用户名/邮箱/电话号码(+国家编码)：',
    ['Verification Code'] = '验证码',
    ['View Favorites'] = '查看收藏',
    ['View Full History'] = '查看完整历史',
    ['View Updates'] = '查看更新',
    ['What issues does this code have?'] = '此代码有什么问题？',
    ['What potential issues could the above code have?'] = '上面代码可能有什么问题？',
    ['What potential issues could the following code have?'] = '下面代码可能有什么问题？',
    ['Wrong username or password'] = '错误的用户名或密码',
    ['You can ask me:'] = '你可以问我：',
    ['You can go to the settings interface to customize the unit test framework for a certain language for better generation results'] = '您可以前往设置界面为特定语言指定单元测试框架，以获得更好的生成效果',
    ["Below is the user's code context, which may be needed for subsequent inquiries."] = '以下是用户代码的上下文，可能在后续询问中会用到。',
    ["Go to 'Extensions' to install"] = '前往“扩展”安装',
    ["Password must be at least 8 characters long and contain at least two of the following: one uppercase letter, one lowercase letter, one number, and one special character. Special characters include: ~`!@#$%^&*()_-+={[}]|:;\"'<,>.?/"] = "密码必须至少8个字符，且包含以下至少两种字符类型：大写字母、小写字母、数字和特殊字符。特殊字符包括：~`!@#$%^&*()_-+={[}]|:;\"'<,>.?/",
    ["Reply same language as the user's input."] = '请完全使用中文回答。',
    ['Enter master password: '] = '请输入主密码：',
}

local function translate(key, ...)
    local lang = Language.display_preference()
    local v = key
    if Fn.startswith(lang, 'zh') then
        v = translations[key] or key
    end
    return Fn.simple_format(v, ...)
end

return translate
