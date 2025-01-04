#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern "C" {
#include <lauxlib.h>
#include <lua.h>

#include <curl/curl.h>
}

#include "curl.h"

extern "C" {

static int l_global_init(lua_State *L) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    return 1;
}

static int l_fetch(lua_State *L) {
    // 1. url
    const char *url = luaL_checkstring(L, 1);
    // 2. options table
    if (strcmp(luaL_typename(L, 2), "table") != 0) {
        luaL_error(L, "Expected a table at index 2");
    }
    // 3. 遍历options table
    lua_pushnil(L);  // 第一个key，nil表示从第一个元素开始
    while (lua_next(L, 2) != 0) {
        // key在-2位置，value在-1位置
        const char *key = lua_tostring(L, -2);  // 获取key
        if (lua_isstring(L, -1)) {
            const char *value = lua_tostring(L, -1);  // 获取string类型的value
            // 处理key和value
            printf("Key: %s, Value: %s\n", key, value);
        } else if (lua_isnumber(L, -1)) {
            double value = lua_tonumber(L, -1);  // 获取number类型的value
            // 处理key和value
            printf("Key: %s, Value: %f\n", key, value);
        } else if (lua_isboolean(L, -1)) {
            bool value = lua_toboolean(L, -1);  // 获取boolean类型的value
            // 处理key和value
            printf("Key: %s, Value: %s\n", key, value ? "true" : "false");
        }
        // 弹出value，保留key用于下一次迭代
        lua_pop(L, 1);
    }
    return 1;
}

static int l_abort(lua_State *L) {
    const char *input = luaL_checkstring(L, 1);
    uint8_t output[16];
    // ...
    lua_pushlstring(L, (const char *) output, 16);
    return 1;
}

static int l_is_active(lua_State *L) {
    const char *input = luaL_checkstring(L, 1);
    uint8_t output[16];
    // ...
    lua_pushlstring(L, (const char *) output, 16);
    return 1;
}

static const luaL_Reg libcurlfunctions[] = {
    { "global_init", l_global_init },
    { "fetch", l_fetch },
    { "abort", l_abort },
    { "is_active", l_is_active },
    { NULL, NULL }
};

int luaopen_libcurl(lua_State *L) {
    lua_newtable(L);
    for (int i = 0; libcurlfunctions[i].name != NULL; i++) {
        lua_pushcfunction(L, libcurlfunctions[i].func);
        lua_setfield(L, -2, libcurlfunctions[i].name);
    }
    return 1;
}
}
