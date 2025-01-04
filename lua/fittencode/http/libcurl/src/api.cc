#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <string_view>
#include <iostream>

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
    std::string_view url = luaL_checkstring(L, 1);
    std::cout << "url: " << url << std::endl;

    // 2. options table
    if (strcmp(luaL_typename(L, 2), "table") != 0) {
        luaL_error(L, "Expected a table at index 2");
    }

    auto curl = curl_easy_init();
    std::cout << "curl: " << curl << std::endl;
    if (!curl) {
        luaL_error(L, "Failed to initialize curl");
    }

    curl_easy_setopt(curl, CURLOPT_URL, url.data());

    // 3. 遍历options table
    lua_pushnil(L); // 第一个key，nil表示从第一个元素开始
    while (lua_next(L, 2) != 0) {
        // key在-2位置，value在-1位置
        std::string_view key = lua_tostring(L, -2); // 获取key
        std::cout << "key: " << key << std::endl;
        if (key == "method") {
            if (lua_isstring(L, -1)) {
                std::string_view value = lua_tostring(L, -1); // 获取string类型的value
                std::cout << "method: " << value << std::endl;
                if (value == "GET") {
                    curl_easy_setopt(curl, CURLOPT_HTTPGET, 1);
                } else if (value == "POST") {
                    curl_easy_setopt(curl, CURLOPT_POST, 1);
                } else {
                    luaL_error(L, "Unsupported method: %s", value.data());
                }
            }
        }
        // 弹出value，保留key用于下一次迭代
        lua_pop(L, 1);
    }

    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        const char *error_msg = curl_easy_strerror(res);
        luaL_error(L, "Failed to fetch url: %s", error_msg);
    }

    curl_easy_cleanup(curl);

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
