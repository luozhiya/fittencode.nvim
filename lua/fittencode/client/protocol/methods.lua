--[[

协议定义文件
* 包括 URLs 和 Methods 两部分
* URLs 定义了一部分固定地址
* Methods 定义了核心服务 API 接口及其参数
  * method: HTTP 请求方法，如 GET、POST、PUT、DELETE, 以及自定义的 OPENLINK
  * url: 对含有多语言版本的，采用 { en = '', ['zh-cn'] = '' } 的形式
  * headers: HTTP 请求头，如 { 'Content-Type' = 'application/json' }
  * query: URL 查询参数，如 `?user_id={{user_id}}&{{platform_info}}` 约定一个接口只能有一种query参数形式
  * body: 请求体，如 `@FittenCode.Protocol.Methods.Login.Payload`
  * response: 响应体，如 `@FittenCode.Protocol.Methods.Login.Response`
  * 注：(`url`/`headers`/`query`) 均支持模版参数，可动态解析，如 `{{user_id}}`、`{{platform_info}}`、`{{access_token}}`、`{{refresh_token}}`、`{{client_token}}`、`{{source}}`

引用资料
* VSCode 插件版本：`fittentech.fitten-code 0.10.127`
* 插件地址： https://marketplace.visualstudio.com/items?itemName=FittenTech.Fitten-Code

]]

---@class FittenCode.Protocol.Methods
local M = {}

-- 接口列表
-- 单一、明确的参数格式更优
local Methods = {
    -- 注册接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `query = username={}&phone={}&email={}&lang={}&timezone={}`
    -- * `body = @FittenCode.Protocol.Methods.Signup.Payload`
    -- * `response = @FittenCode.Protocol.Methods.Signup.Response`
    signup = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/signup',
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                ['_'] = 0,
                username = '{{signup_username}}',
                phone = '{{signup_phone}}',
                email = '{{signup_email}}',
                lang = '{{langs}}',
                timezone = '{{timezone}}',
            },
        }
    },
    -- 帐号密码登录接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `query = {}`
    -- * `body = @FittenCode.Protocol.Methods.Login.Payload`
    -- * `response = @FittenCode.Protocol.Methods.Login.Response`
    login = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/auth/login',
    },
    -- 通过手机号更改密码接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.UpdatePassword.Payload`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.UpdatePassword.Response`
    update_password = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/update_password',
    },
    -- 通过邮箱更改密码接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.UpdatePasswordEmail.Payload`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.UpdatePasswordEmail.Response`
    update_password_email = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/update_password_email',
    },
    -- 发送邮箱验证码接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.EmailCode.Payload`
    -- * `query = ?email={}`
    -- * `response = @FittenCode.Protocol.Methods.EmailCode.Response`
    email_code = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/email_code',
        query = {
            dynamic = {
                email = '{{email}}'
            },
        }
    },
    -- 发送手机验证码接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.PhoneCode.Payload`
    -- * `query = ?phone={}`
    -- * `response = @FittenCode.Protocol.Methods.PhoneCode.Response`
    phone_code = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/phone_code',
        query = {
            dynamic = {
                phone = '{{phone}}'
            },
        }
    },
    -- 获取用户信息接口
    -- * `method = GET`
    -- * `headers = { 'Authorization' = 'Bearer {{access_token}}' }`
    -- * `body = {}`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.UserInfo.Response`
    user_info = {
        method = 'GET',
        headers = { ['Authorization'] = 'Bearer {{access_token}}' },
        url = '/codeuser/user_info',
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
        query = {
            dynamic = {
                ft_token = '{{ft_token}}'
            }
        }
    },
    -- 刷新 refresh_token
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.RefreshRefreshToken.Payload`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.RefreshRefreshToken.Response`
    refresh_refresh_token = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/auth/refresh_refresh_token'
    },
    -- 刷新 access_token
    -- * `method = POST`
    -- * `body = {}`
    -- * `headers = { 'Authorization' = 'Bearer {{access_token}}', 'Content-Type' = 'application/json' }`
    -- * `query = {}`
    -- * `response = @FittenCode.Protocol.Methods.RefreshAccessToken.Response`
    refresh_access_token = {
        method = 'POST',
        headers = {
            ['Authorization'] = 'Bearer {{access_token}}',
            ['Content-Type'] = 'application/json'
        },
        url = '/codeuser/auth/refresh_access_token'
    },
    -- 第三方登录接口
    -- * `method = OPENLINK`
    -- * `query = ?source={}&client_token={}`
    fb_sign_in = {
        method = 'OPENLINK',
        url = '/codeuser/fb_sign_in',
        query = {
            dynamic = {
                source = '{{sign_in_source}}',
                client_token = '{{client_token}}',
            },
        }
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
        query = {
            dynamic = {
                client_token = '{{client_token}}',
            },
        }
    },
    -- 当用户点击登录或者注册按钮时，用于后台统计用户行为
    -- * `method = GET`
    -- * `mode = cors`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * ```
    --    query = &type={}?user_id={}
    --    支持的 type (事实上不同的 type 对应不同的 query 参数，暂不支持):
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
        query = {
            dynamic = {
                type = '{{click_count_type}}',
                user_id = '{{user_id}}',
            },
        }
    },
    privacy = {
        method = 'OPENLINK',
        url = {
            en = '/codeuser/privacy_en',
            ['zh-cn'] = '/codeuser/privacy'
        }
    },
    agreement = {
        method = 'OPENLINK',
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
    -- * `query = ?{{completion_statistics}}`
    statistic_log = {
        method = 'GET',
        mode = 'cors',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/statistic_log',
        query = {
            ref = { '{{completion_statistics}}' },
        }
    },
    -- 发送统计日志接口
    -- * `method = GET`
    -- * `mode = cors`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?tracker={}` tracker=后面接一个json字符串
    statistic_log_v2 = {
        method = 'GET',
        mode = 'cors',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/statistic_log',
        query = {
            dynamic = {
                tracker = '{{tracker}}',
            },
        }
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
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                plan_name = '{{plan_name}}',
                ft_token = '{{ft_token}}',
            },
        }
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
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                user_id = '{{user_id}}',
            },
        }
    },
    -- 获取用户的 Completion 版本号，该值影响 generate_one_stage_auth 接口
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?ft_token={}`
    -- * `response = @FittenCode.Protocol.Methods.GetCompletionVersion.Response`
    get_completion_version = {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeuser/get_completion_version',
        query = {
            dynamic = {
                ft_token = '{{ft_token}}',
            },
        }
    },
    -- 当用户 Accept 代码补全时，向服务器发送事件
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.Accept.Payload`
    -- * `query = {}`
    accept = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/completion/accept/{{user_id}}'
    },
    -- 生成一阶段补全代码，兼容 Vim 的版本，以及为集成到其他插件提供最简接口
    generate_one_stage = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/completion/generate_one_stage/{{user_id}}',
        query = {
            ref = { '{{platform_info}}' },
        }
    },
    -- 生成一阶段补全代码，有多个版本
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json', 'Content-Encoding' = 'gzip' }`
    -- * `body = @FittenCode.Protocol.Methods.GenerateOneStageAuth.Payload`
    -- * `query = ?{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.GenerateOneStageAuth.Response`
    -- * `completion_version = { '', '2_1', '2_2', '2_3' }`
    generate_one_stage_auth = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json', ['Content-Encoding'] = 'gzip', ['Authorization'] = 'Bearer {{access_token}}' },
        url = '/codeapi/completion{{completion_version}}/generate_one_stage_auth/{{user_id}}',
        query = {
            ref = { '{{platform_info}}' },
        }
    },
    -- 对话接口 Chat (Fast/Search @FCPS)，以流的形式接受数据
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json', 'Authorization' = 'Bearer {{access_token}}' }`
    -- * `body = @FittenCode.Protocol.Methods.ChatAuth.Payload`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.ChatAuth.Response`
    chat_auth = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bearer {{access_token}}' },
        url = '/codeapi/chat_auth',
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                ft_token = '{{ft_token}}',
            },
        }
    },
    -- 当用户选择插入或复制对话内容时，向服务器发送事件
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.Feedback.Payload`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = {}`
    feedback = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/chat/feedback',
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                ft_token = '{{ft_token}}',
            },
        }
    },
    -- 检测用户的邀请码
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.CheckInviteCode.Payload`
    -- * `query = ?code={}`
    -- * `response = @FittenCode.Protocol.Methods.CheckInviteCode.Response`
    check_invite_code = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/chat/check_invite_code',
        query = {
            dynamic = {
                code = '{{invite_code}}',
            },
        }
    },
    -- 发送 RAG 聊天信息，当使用 @project/@workspace 时，调用此接口
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.RagChat.Payload`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.RagChat.Response`
    rag_chat = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/chat',
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                ft_token = '{{ft_token}}',
            },
        }
    },
    -- 获取知识库信息
    -- * `method = GET`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = {}`
    -- * `query = ?FT_Token={}`
    -- * `response = @FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response`
    knowledge_base_info = {
        method = 'GET',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/knowledgeBaseInfo',
        query = {
            dynamic = {
                FT_Token = '{{ft_token}}',
            },
        }
    },
    -- 获取本地知识库的引用
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Payload`
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
    -- * `body = @FittenCode.Protocol.Methods.CreateKnowledgeBase.Payload`
    -- * `query = {}`
    create_knowledge_base = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/createKnowledgeBase',
    },
    -- 加入指定 ID 的知识库
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.JoinKnowledgeBase.Payload`
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
    -- * `body = @FittenCode.Protocol.Methods.GetKnowledgeBase.Payload`
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
    -- * `body = @FittenCode.Protocol.Methods.UpdateKnowledgeBase.Payload`
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
    -- * `body = @FittenCode.Protocol.Methods.DeleteKnowledgeBase.Payload`
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
        query = {
            dynamic = {
                FT_Token = '{{ft_token}}',
                targetDirId = '{{target_dir_id}}',
            }
        }
    },
    -- 上传文件
    -- * `method = POST`
    -- * `headers = {}`
    -- * `body = @FittenCode.Protocol.Methods.UploadLargeFile.Payload`
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
    -- * `body = @FittenCode.Protocol.Methods.DeleteFile.Payload`
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
    -- * `body = @FittenCode.Protocol.Methods.NeedUpdateProject.Payload`
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
    -- * `body = @FittenCode.Protocol.Methods.UpdateProject.Payload`
    -- * `query = ?ft_token={}`
    -- * `response = @FittenCode.Protocol.Methods.UpdateProject.Response`
    update_project = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/update_project',
        query = {
            dynamic = {
                ft_token = '{{ft_token}}',
            },
        }
    },
    -- 保存文件和目录名
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Payload`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Response`
    save_file_and_directory_names = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/save_file_and_directory_names',
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                ft_token = '{{ft_token}}',
            },
        }
    },
    -- 添加文件和目录
    -- * `method = POST`
    -- * `headers = { 'Content-Type' = 'application/json' }`
    -- * `body = @FittenCode.Protocol.Methods.AddFilesAndDirectories.Payload`
    -- * `query = ?ft_token={}&{platform_info}`
    -- * `response = @FittenCode.Protocol.Methods.AddFilesAndDirectories.Response`
    add_files_and_directories = {
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        url = '/codeapi/rag/add_files_and_directories',
        query = {
            ref = { '{{platform_info}}' },
            dynamic = {
                ft_token = '{{ft_token}}',
            },
        }
    },
}

for _, method in pairs(Methods) do
    method.type = 'method'
end

M.__index = function(_, k)
    if Methods[k] then
        return vim.deepcopy(Methods[k])
    end
end
setmetatable(M, M)

return M
