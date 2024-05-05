#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <curl/curl.h>
#include <lua.h>

int curlua_global_init(lua_State* L);
int curlua_global_cleanup(lua_State* L);

int curlua_easy_init(lua_State* L);
int curlua_easy_cleanup(lua_State* L);
int curlua_easy_setopt(lua_State* L);
int curlua_easy_perform(lua_State* L);

#ifdef __cplusplus
}
#endif
