-- 协议定义文件
-- * 包括 URLs 和 Methods 两部分
-- * URLs 定义了一部分固定地址
-- * Methods 定义了核心服务 API 接口及其参数
-- * 对含有多语言版本的，采用 { en = '', zh = '' } 的形式
-- * 参考版本：`fittentech.fitten-code 0.10.119`
-- * 插件地址： https://marketplace.visualstudio.com/items?itemName=FittenTech.Fitten-Code
---@class FittenCode.Protocol
local Protocol = {}

---@type FittenCode.Protocol.URLs
Protocol.URLs = {
    -- Account
    register = 'https://fc.fittentech.com/',
    -- 通过第三方注册后需要调用此接口，后台做统计
    register_cvt = 'https://fc.fittentech.com/cvt/register',
    question = 'https://code.fittentech.com/assets/images/blog/QR.jpg',
    tutor = 'https://code.fittentech.com/desc-vim',
    try = 'https://code.fittentech.com/try',
}

-- 接口列表
---@type FittenCode.Protocol.Methods
Protocol.Methods = {
    -- 帐号密码登录接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `query = ?user_id={}&{platform_info}`
    -- * `body = @FittenCode.Protocol.Methods.Login.Body`
    -- * `response = @FittenCode.Protocol.Methods.Login.Response`
    login = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/auth/login',
        query = '?user_id={{user_id}}&{{platform_info}}',
    },
    -- 根据 ft_token 获取 access_token
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?ft_token={}`
    auto_login = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/auth/auto_login',
        query = '?ft_token={{ft_token}}'
    },
    -- 刷新 refresh_token
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.RefreshRefreshToken.Body`
    -- * `query = {}`
    refresh_refresh_token = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/auth/refresh_refresh_toke'
    },
    -- 刷新 access_token
    -- * `method = POST`
    -- * `body = {}`
    -- * `headers = { 'Authorization' = 'Bearer {{access_token}}', 'Content-Type' = 'application/json' }`
    -- * `query = {}`
    refresh_access_token = {
        method = 'POST',
        headers = {
            ['Authorization'] = 'Bearer {{access_token}}',
            ['Content-Type'] = 'application/json'
        },
        url = '/codeuser/auth/refresh_access_token'
    },
    -- 第三方登录接口
    -- * `method = OpenLink`
    -- * `query = ?source={}&client_token={}`
    fb_sign_in = {
        method = 'OpenLink',
        url = '/codeuser/fb_sign_in',
        query = '?source={{source}}&client_token={{client_token}}'
    },
    -- 监听第三方登录状态接口
    -- * `method = GET`
    -- * `headers = {}`
    -- * `body = {}`
    -- * `query = ?client_token={}`
    -- * `response = @FittenCode.Protocol.Methods.FBCheckLoginAuth.Response`
    fb_check_login_auth = {
        method = 'GET',
        url = '/codeuser/fb_check_login_auth',
        query = '?client_token={{client_token}}'
    },
    -- 当用户点击登录或者注册按钮时，用于后台统计用户行为
    -- * `method = GET`
    -- * `mode = cors`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * ```
    --    query = &type={}?user_id={}
    --    支持的 type:
    --    login
    --    register
    --    register_ide
    --    register_wx
    --    login_wx
    --    register_fb
    --    login_fb
    --    page_login
    --    page_register
    --    page_forgot_password
    --    page_wechat_login
    --    NotificationGet
    --    NotificationDissmiss
    --    NotificationDetail
    -- ```
    click_count = {
        method = 'GET',
        url = '/codeuser/click_count',
        query = '&type={{click_count_type}}?user_id={{user_id}}'
    },
    privacy = {
        method = 'OpenLink',
        url = {
            en = '/codeuser/privacy_en',
            ['zh-cn'] = '/codeuser/privacy'
        }
    },
    agreement = {
        method = 'OpenLink',
        url = {
            en = '/codeuser/agreement_en',
            ['zh-cn'] = '/codeuser/agreement'
        }
    },
    -- 发送统计日志接口
    -- * `method = GET`
    -- * `mode = cors`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?tracker={}`
    statistic_log = {
        method = 'GET',
        mode = 'cors',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/statistic_log',
        query = '?tracker={{tracker}}'
    },
    -- 参加灰度测试接口
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?plan_name={}&ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.GrayTest.Response`
    gray_test = {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/gray_test',
        query = '?plan_name={{plan_name}}&ft_token={{ft_token}}&{{platform_info}}'
    },
    -- 检查用户是否有 Project Completion 权限
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?user_id={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.PCCheckAuth.Response`
    pc_check_auth = {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/pc_check_auth',
        query = '?user_id={{user_id}}&{{platform_info}}'
    },
    -- 获取用户的 Completion 版本号，该值影响 generate_one_stage 接口
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?ft_token={}`
    -- * `response = @FittenCode.Protocol.Methods.GetCompletionVersion.Response`
    get_completion_version = {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/get_completion_version',
        query = '?ft_token={{ft_token}}'
    },
    -- 当用户 Accept 代码补全时，向服务器发送事件
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.Accept.Body`
    -- * `query = {}`
    accept = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/completion/accept/{{user_id}}'
    },
    -- 生成一阶段补全代码，有多个版本
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json', 'Content-Encoding' = 'gzip' }`
    -- * `body = @FittenCode.Protocol.Methods.GenerateOneStage.Body`
    -- * `query = ?{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.GenerateOneStage.Response`
    -- * `version = { '', '2_1', '2_2', '2_3' }`
    generate_one_stage_auth = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json', ['Content-Encoding'] = 'gzip' },
        url = '/codeapi/completion{{completion_version}}/generate_one_stage_auth/{{user_id}}',
        query = '?{{platform_info}}',
    },
    -- 对话接口 Chat (Fast/Search @FCPS)，以流的形式接受数据
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.ChatAuth.Body`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.ChatAuth.Response`
    chat_auth = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/chat_auth',
        query = '?ft_token={{ft_token}}&{{platform_info}}'
    },
    -- 当用户选择插入或复制对话内容时，向服务器发送事件
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.Feedback.Body`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = {}`
    feedback = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/chat/feedback',
        query = '?ft_token={{ft_token}}&{{platform_info}}'
    },
    -- 检测用户的邀请码
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.CheckInviteCode.Body`
    -- * `query = ?code={}`
    -- * `response = @FittenCode.Protocol.Methods.CheckInviteCode.Response`
    check_invite_code = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/chat/check_invite_code',
        query = '?code={{invite_code}}'
    },
    -- 发送 RAG 聊天信息，当使用 @project/@workspace 时，调用此接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.RagChat.Body`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.RagChat.Response`
    rag_chat = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/chat',
        query = '?ft_token={{ft_token}}&{{platform_info}}'
    },
    -- 获取知识库信息
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?FT_Token={}`
    -- * `response = @FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response`
    knowledge_base_info = {
        method = 'GET',
        url = '/codeapi/rag/knowledgeBaseInfo',
        query = '?FT_Token={{ft_token}}'
    },
    -- 获取本地知识库的引用
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Body`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Response`
    get_local_knowledge_base_refs = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/getLocalKnowledgeBaseRefs',
    },
    -- 创建知识库
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.CreateKnowledgeBase.Body`
    -- * `query = {}`
    create_knowledge_base = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/createKnowledgeBase',
    },
    -- 加入指定 ID 的知识库
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.JoinKnowledgeBase.Body`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.JoinKnowledgeBase.Response`
    join_knowledge_base = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/joinKnowledgeBase',
    },
    -- 根据 ID 获取知识库信息
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.GetKnowledgeBase.Body`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.GetKnowledgeBase.Response`
    get_knowledge_base = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/getKnowledgeBase',
    },
    -- 更新知识库
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.UpdateKnowledgeBase.Body`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.UpdateKnowledgeBase.Response`
    update_knowledge_base = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/updateKnowledgeBase',
    },
    -- 删除知识库
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.DeleteKnowledgeBase.Body`
    -- * `query = {}`
    delete_knowledge_base = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/deleteKnowledgeBase'
    },
    -- 获取文件列表
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?FT_Token={}&targetDirId={}`
    -- * `response = @FittenCode.Protocol.Methods.GetFilesList.Response`
    files_name_list = {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/filesNameList',
        query = '?FT_Token={{ft_token}}&targetDirId={{target_dir_id}}'
    },
    -- 上传文件
    -- * `method = POST`
    -- * `headers = {}`
    -- * `body = @FittenCode.Protocol.Methods.UploadLargeFile.Body`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.UploadLargeFile.Response`
    upload_large_file = {
        method = 'POST',
        headers = {},
        url = '/codeapi/rag/upload_large_file'
    },
    -- 删除文件
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.DeleteFile.Body`
    -- * `query = {}`
    -- * `response = {}`
    delete_file = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/deleteFile'
    },
    -- 检测是否需要更新项目
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.NeedUpdateProject.Body`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.NeedUpdateProject.Response`
    need_update_project = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/need_update_project',
    },
    -- 更新项目
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.UpdateProject.Body`
    -- * `query = ?ft_token={}`
    -- * `response = @FittenCode.Protocol.Methods.UpdateProject.Response`
    update_project = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/update_project',
        query = '?ft_token={{ft_token}}'
    },
    -- 保存文件和目录名
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Body`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Response`
    save_file_and_directory_names = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/save_file_and_directory_names',
        query = '?ft_token={{ft_token}}&{{platform_info}}'
    },
    -- 添加文件和目录
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.AddFilesAndDirectories.Body`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.AddFilesAndDirectories.Response`
    add_files_and_directories = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/add_files_and_directories',
        query = '?ft_token={{ft_token}}&{{platform_info}}'
    },
}

return Protocol
