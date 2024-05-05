#include <lua.h>
#include <lauxlib.h>

#include "implementation.h"

const luaL_Reg curlua[] = {
    {"curlua_global_init", curlua_global_init},
    {"curlua_global_cleanup", curlua_global_cleanup},
    {"curlua_easy_init", curlua_easy_init},
    {"curlua_easy_cleanup", curlua_easy_cleanup},
    {"curlua_easy_setopt", curlua_easy_setopt},
    {"curlua_easy_perform", curlua_easy_perform},
    {NULL, NULL}  // Sentinel
};

int luaopen_libcurlua(lua_State* L) {
    luaL_newlib(L, curlua);
    return 1;
}
