------------------------------------------------
-- Common Types for FittenCode.Protocol
------------------------------------------------

---@class FittenCode.Protocol.Element
---@field method string
---@field mode? string
---@field url FittenCode.Protocol.Element.URL
---@field headers? table<string, string>
---@field body? table<string, any>
---@field query? string|table<string, any>
---@field response? table<string, any>
---@field type? string 'method'|'url'

---@alias FittenCode.Protocol.Element.URL string|table<string, string>

---@class FittenCode.Protocol.Types.UserInfo
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
---@field wechat_info? FittenCode.Protocol.Types.UserInfo.WechatInfo
---@field firebase_info? FittenCode.Protocol.Types.UserInfo.FirebaseInfo
---@field client_token string
---@field client_time number
---@field company string

---@class FittenCode.Protocol.Types.UserInfo.WechatInfo
---@field nickname string

---@class FittenCode.Protocol.Types.UserInfo.FirebaseInfo
---@field display_name string
---@field email string

---@class FittenCode.Protocol.Types.Authorization
---@field access_token string
---@field refresh_token string
---@field user_info FittenCode.Protocol.Types.UserInfo

------------------------------------------------
-- Signup
------------------------------------------------

---@class FittenCode.Protocol.Methods.Signup.Body
---@field username string
---@field password string
---@field phone string
---@field email string
---@field code string
---@field company string

---@class FittenCode.Protocol.Methods.Signup.Response
---@field status_code number
---@field msg string

------------------------------------------------
-- Login
------------------------------------------------

---@class FittenCode.Protocol.Methods.Login.Body
---@field username string
---@field password string

---@class FittenCode.Protocol.Methods.Login.ResponseError
---@field data string
---@field status_code number
---@field msg string

---@class FittenCode.Protocol.Methods.Login.Response : FittenCode.Protocol.Types.Authorization

------------------------------------------------
-- UpdatePassword
------------------------------------------------

---@class FittenCode.Protocol.Methods.UpdatePassword.Body
---@field username string
---@field password string
---@field phone string
---@field email string
---@field code string

---@class FittenCode.Protocol.Methods.UpdatePassword.Response
---@field status_code number
---@field msg string

------------------------------------------------
-- UpdatePasswordEmail
------------------------------------------------

---@class FittenCode.Protocol.Methods.UpdatePasswordEmail.Body
---@field username string
---@field password string
---@field phone string
---@field code string
---@field email string

---@class FittenCode.Protocol.Methods.UpdatePasswordEmail.Response
---@field status_code number
---@field msg string

------------------------------------------------
-- EmailCode
------------------------------------------------

---@class FittenCode.Protocol.Methods.EmailCode.Body
---@field phone string

---@class FittenCode.Protocol.Methods.EmailCode.Response
---@field status_code number
---@field msg string

------------------------------------------------
-- PhoneCode
------------------------------------------------

---@class FittenCode.Protocol.Methods.PhoneCode.Body
---@field phone string

---@class FittenCode.Protocol.Methods.PhoneCode.Response
---@field status_code number
---@field msg string

------------------------------------------------
-- UserInfo
------------------------------------------------

---@class FittenCode.Protocol.Methods.UserInfo.Response : FittenCode.Protocol.Types.UserInfo

------------------------------------------------
-- FBCheckLoginAuth
------------------------------------------------

---@class FittenCode.Protocol.Methods.FBCheckLoginAuth.Response : FittenCode.Protocol.Types.Authorization
---@field create boolean

------------------------------------------------
-- FCCheckAuth
------------------------------------------------

-- 相应示例：`yes-4`
---@alias FittenCode.Protocol.Methods.PCCheckAuth.Response string

------------------------------------------------
-- GetCompletionVersion
------------------------------------------------

-- 相应示例：`"1"`
---@alias FittenCode.Protocol.Methods.GetCompletionVersion.Response string

------------------------------------------------
-- Accept
------------------------------------------------

---@class FittenCode.Protocol.Methods.Accept.Body
---@field request_id string

------------------------------------------------
-- RefreshRefreshToken
------------------------------------------------

---@class FittenCode.Protocol.Methods.RefreshRefreshToken.Body
---@field refresh_token string

------------------------------------------------
-- ChatAuth
------------------------------------------------

---@class FittenCode.Protocol.Methods.ChatAuth.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.ChatAuth.Body.MetaDatas

---@class FittenCode.Protocol.Methods.ChatAuth.Body.MetaDatas
---@field project_id string

---@class FittenCode.Protocol.Methods.ChatAuth.Response.ChunkUsage
---@field input_tokens? string
---@field output_tokens? string
---@field status? string

---@class FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
---@field delta? string
---@field tracedata? string
---@field usage? FittenCode.Protocol.Methods.ChatAuth.Response.ChunkUsage

---@alias FittenCode.Protocol.Methods.ChatAuth.Response table<FittenCode.Protocol.Methods.ChatAuth.Response.Chunk>

------------------------------------------------
-- RagChat
------------------------------------------------

---@class FittenCode.Protocol.Methods.RagChat.Body : FittenCode.Protocol.Methods.ChatAuth.Body
---@class FittenCode.Protocol.Methods.RagChat.Response.Chunk : FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
---@alias FittenCode.Protocol.Methods.RagChat.Response table<FittenCode.Protocol.Methods.RagChat.Response.Chunk>

------------------------------------------------
-- KnowledgeBaseInfo
------------------------------------------------

---@class FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response.KnowledgeBase
---@field dirName string
---@field id string
---@field userId string

---@alias FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response table<FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response.KnowledgeBase>

------------------------------------------------
-- DeleteKnowledgeBase
------------------------------------------------

---@class FittenCode.Protocol.Methods.DeleteKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.DeleteKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.DeleteKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field FT_Token string
---@field KB_ID string

------------------------------------------------
-- CreateKnowledgeBase
------------------------------------------------

---@class FittenCode.Protocol.Methods.CreateKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.CreateKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.CreateKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field FT_Token string
---@field description string
---@field creatorName string

------------------------------------------------
-- GetFilesList
------------------------------------------------

---@class FittenCode.Protocol.Methods.GetFilesList.Response
---@field time string
---@field filesName table<string>

------------------------------------------------
-- DeleteFile
------------------------------------------------

---@class FittenCode.Protocol.Methods.DeleteFile.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.DeleteFile.Body.MetaDatas

---@class FittenCode.Protocol.Methods.DeleteFile.Body.MetaDatas
---@field knowledgeBaseName string
---@field fileName string
---@field FT_Token string
---@field knowledgeBaseId string

------------------------------------------------
-- UploadLargeFile
------------------------------------------------

-- FormData
---@class FittenCode.Protocol.Methods.UploadLargeFile.Body
---@field chunk string
---@field index string
---@field total_chunks string
---@field knowledge_base_name string
---@field FT_Token string
---@field knowledge_base_id string

---@class FittenCode.Protocol.Methods.UploadLargeFile.Response
---@field message string

------------------------------------------------
-- UpdateProject
------------------------------------------------

---@class FittenCode.Protocol.Methods.UpdateProject.Body
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.UpdateProject.Body.MetaDatas

---@class FittenCode.Protocol.Methods.UpdateProject.Body.MetaDatas
---@field project_id string
---@field project_name string

------------------------------------------------
-- SaveFileAndDirectoryNames
------------------------------------------------

---@class FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Body.MetaDatas

---@class FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Body.MetaDatas
---@field file_dir_names table
---@field file_hash table

------------------------------------------------
-- AddFilesAndDirectories
------------------------------------------------

---@class FittenCode.Protocol.Methods.AddFilesAndDirectories.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.AddFilesAndDirectories.Body.MetaDatas

---@class FittenCode.Protocol.Methods.AddFilesAndDirectories.Body.MetaDatas
---@field file_name string
---@field file_paths table

------------------------------------------------
-- GetLocalKnowledgeBaseRefs
------------------------------------------------

---@class FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Body.MetaDatas

---@class FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Body.MetaDatas
---@field targetId string
---@field inputs string
---@field FT_Token string
---@field keywords table

------------------------------------------------
-- JoinKnowledgeBase
------------------------------------------------

---@class FittenCode.Protocol.Methods.JoinKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.JoinKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.JoinKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field description string
---@field FT_Token string
---@field ID string

------------------------------------------------
-- GetKnowledgeBase
------------------------------------------------

---@class FittenCode.Protocol.Methods.GetKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.GetKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.GetKnowledgeBase.Body.MetaDatas
---@field ID string

---@class FittenCode.Protocol.Methods.GetKnowledgeBase.Response
---@field knowledgeBaseName string
---@field description string

------------------------------------------------
-- UpdateKnowledgeBase
------------------------------------------------

---@class FittenCode.Protocol.Methods.UpdateKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.UpdateKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.UpdateKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field description string
---@field FT_Token string
---@field ID string

------------------------------------------------
-- Feedback
------------------------------------------------

---@class FittenCode.Protocol.Methods.Feedback.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.Feedback.Body.MetaDatas

---@class FittenCode.Protocol.Methods.Feedback.Body.MetaDatas
---@field feedback_type string

------------------------------------------------
-- CheckInviteCode
------------------------------------------------

---@class FittenCode.Protocol.Methods.CheckInviteCode.Body
---@field inputs string

---@class FittenCode.Protocol.Methods.CheckInviteCode.Response
---@field status string

------------------------------------------------
-- GrayTest
------------------------------------------------

---@alias FittenCode.Protocol.Methods.GrayTest.Response number

---@class FittenCode.Protocol.Methods
---@field login FittenCode.Protocol.Element
---@field auto_login FittenCode.Protocol.Element
---@field refresh_refresh_token FittenCode.Protocol.Element
---@field refresh_access_token FittenCode.Protocol.Element
---@field fb_sign_in FittenCode.Protocol.Element
---@field fb_check_login_auth FittenCode.Protocol.Element
---@field click_count FittenCode.Protocol.Element
---@field statistic_log FittenCode.Protocol.Element
---@field statistic_log_v2 FittenCode.Protocol.Element
---@field gray_test FittenCode.Protocol.Element
---@field pc_check_auth FittenCode.Protocol.Element
---@field get_completion_version FittenCode.Protocol.Element
---@field accept FittenCode.Protocol.Element
---@field generate_one_stage_auth FittenCode.Protocol.Element
---@field chat_auth FittenCode.Protocol.Element
---@field feedback FittenCode.Protocol.Element
---@field check_invite_code FittenCode.Protocol.Element
---@field rag_chat FittenCode.Protocol.Element
---@field knowledge_base_info FittenCode.Protocol.Element
---@field get_local_knowledge_base_refs FittenCode.Protocol.Element
---@field create_knowledge_base FittenCode.Protocol.Element
---@field join_knowledge_base FittenCode.Protocol.Element
---@field get_knowledge_base FittenCode.Protocol.Element
---@field update_knowledge_base FittenCode.Protocol.Element
---@field delete_knowledge_base FittenCode.Protocol.Element
---@field files_name_list FittenCode.Protocol.Element
---@field upload_large_file FittenCode.Protocol.Element
---@field delete_file FittenCode.Protocol.Element
---@field need_update_project FittenCode.Protocol.Element
---@field update_project FittenCode.Protocol.Element
---@field save_file_and_directory_names FittenCode.Protocol.Element
---@field add_files_and_directories FittenCode.Protocol.Element

---@class FittenCode.Protocol.URLs
---@field register FittenCode.Protocol.Element
---@field register_cvt FittenCode.Protocol.Element
---@field question FittenCode.Protocol.Element
---@field tutor FittenCode.Protocol.Element
---@field try FittenCode.Protocol.Element
