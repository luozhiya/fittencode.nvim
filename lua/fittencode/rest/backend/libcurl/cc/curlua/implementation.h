#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <curl/curl.h>
#include <lua.h>

int curlua_global_init(lua_State* L);

#ifdef __cplusplus
}
#endif
