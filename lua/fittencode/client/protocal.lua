-- 协议定义文件
-- * 包括 URLs 和 Methods 两部分
-- * URLs 定义了一部分固定地址
-- * Methods 定义了核心服务 API 接口及其参数
-- * 对含有多语言版本的，采用 { en = '', zh = '' } 的形式
---@class FittenCode.Protocol
local Protocol = {}

---@class FittenCode.Protocol.Element
---@field method string
---@field mode? string
---@field url FittenCode.Protocol.Element.URL
---@field headers? table<string, string>
---@field body? table<string, any>
---@field query? string
---@field response? table<string, any>

---@alias FittenCode.Protocol.Element.URL string|table<string, string>

-- 固定地址
---@alias FittenCode.Protocol.URLs table<string, FittenCode.Protocol.Element.URL>

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
-- * 参考版本：`fittentech.fitten-code 0.10.119`
-- * 插件地址： https://marketplace.visualstudio.com/items?itemName=FittenTech.Fitten-Code
---@alias FittenCode.Protocol.Methods table<string, FittenCode.Protocol.Element>

---@class FittenCode.Protocol.Methods.Login.Body
---@field username string
---@field password string

---@class FittenCode.Protocol.Methods.Login.Response.UserInfo
---@field user_id string
---@field username string
---@field phone string
---@field nickname string
---@field email string
---@field token string
---@field registration_time string
---@field user_type string
---@field account_status string
---@field register_username string
---@field wechat_info? table<string, any>
---@field firebase_info? table<string, any>
---@field client_token string
---@field client_time number
---@field company string

---@class FittenCode.Protocol.Methods.Login.Response
---@field access_token string
---@field refresh_token string
---@field user_info FittenCode.Protocol.Methods.Login.Response.UserInfo

---@class FittenCode.Protocol.Methods.FBCheckLoginAuth.Response : FittenCode.Protocol.Methods.Login.Response
---@field create boolean

-- 相应示例：`yes-4`
---@alias FittenCode.Protocol.Methods.PCCheckAuth.Response string

-- 相应示例：`"1"`
---@alias FittenCode.Protocol.Methods.GetCompletionVersion.Response string

---@class FittenCode.Protocol.Methods.Accept.Body
---@field request_id string

---@class FittenCode.Protocol.Methods.RefreshRefreshToken.Body
---@field refresh_token string

---@class FittenCode.Protocol.Methods.ChatAuth.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.ChatAuth.Body.MetaDatas

---@class FittenCode.Protocol.Methods.ChatAuth.Body.MetaDatas
---@field project_id string

---@class FittenCode.Protocol.Methods.ChatAuth.Response
---@field delta string
---@field tracedata string

---@type FittenCode.Protocol.Methods
Protocol.Methods = {
    -- 帐号密码登录接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `query = ?user_id={}&{platform_info}`
    -- * `body = @FittenCode.Protocol.Methods.Account.Login.Body`
    -- * `response = @FittenCode.Protocol.Methods.Account.Login.Response`
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
    -- * `body = @FittenCode.Protocol.Methods.Account.RefreshRefreshToken.Body`
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
    -- * `response = @FittenCode.Protocol.Methods.Account.FBCheckLoginAuth.Response`
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
    -- 检查用户是否有 Project Completion 权限
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?user_id={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.Account.PCCheckAuth.Response`
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
    -- * `response = @FittenCode.Protocol.Methods.Account.GetCompletionVersion.Response`
    get_completion_version = {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/get_completion_version',
        query = '?ft_token={{ft_token}}'
    },
    -- 当用户 Accept 代码补全时，向服务器发送事件
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.Completion.Accept.Body`
    -- * `query = {}`
    accept = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/completion/accept/{{user_id}}'
    },
    -- 生成一阶段补全代码，有多个版本
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json', 'Content-Encoding' = 'gzip' }`
    -- * `body = @FittenCode.Protocol.Methods.Completion.GenerateOneStage.Body`
    -- * `query = ?{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.Completion.GenerateOneStage.Response`
    -- * `version = { '', '2_1', '2_2', '2_3' }`
    generate_one_stage_auth = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json', ['Content-Encoding'] = 'gzip' },
        url = '/codeapi/completion{{completion_version}}/generate_one_stage_auth/{{user_id}}',
        query = '?{{platform_info}}',
    },
    -- 对话接口 Chat (Fast/Search @FCPS)，以流的形式接受数组
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.Chat.ChatAuth.Body`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.Chat.ChatAuth.Response`
    chat_auth = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/chat_auth',
        query = '?ft_token={{ft_token}}&{{platform_info}}'
    },
    rag_chat = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/chat'
    },
    knowledge_base_info = '/codeapi/rag/knowledgeBaseInfo',
    delete_knowledge_base = '/codeapi/rag/deleteKnowledgeBase',
    create_knowledge_base = '/codeapi/rag/createKnowledgeBase',
    files_name_list = '/codeapi/rag/filesNameList', -- ?targetDirName=
    delete_file = '/codeapi/rag/deleteFile',
    upload = '/codeapi/rag/upload',
    update_project = '/codeapi/rag/update_project', -- ?ft_token=
    save_file_and_directory_names = '/codeapi/rag/save_file_and_directory_names',
    add_files_and_directories = '/codeapi/rag/add_files_and_directories',
}

return Protocol
