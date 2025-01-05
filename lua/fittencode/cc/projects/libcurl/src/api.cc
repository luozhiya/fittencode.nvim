#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <format>
#include <iostream>
#include <string_view>

using namespace std::literals;

extern "C" {
#include <curl/curl.h>
}

#include <lua.hpp>

static std::string readBuffer;

extern "C" {

static int l_global_init(lua_State *L) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    return 1;
}

static size_t l_easy_writefunction(void *contents, size_t size, size_t nmemb, void *stream) {
    size_t totalSize = size * nmemb;
    readBuffer.append(reinterpret_cast<char *>(contents), totalSize);
    lua_State *L = (lua_State *) stream;
    lua_getfield(L, -1, "on_stream");
    lua_pushlstring(L, (char *) contents, nmemb * size);
    lua_call(L, 1, 0);
    return nmemb * size;
}

static int l_fetch(lua_State *L) {
    readBuffer.clear();

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

    int on_create = LUA_REFNIL;
    int on_input = LUA_REFNIL;
    int on_once = LUA_REFNIL;
    int on_stream = LUA_REFNIL;
    int on_error = LUA_REFNIL;
    int on_exit = LUA_REFNIL;

    // 3. 遍历options table
    // std::cout << lua_gettop(L) << std::endl;
    lua_pushnil(L); // 第一个key，nil表示从第一个元素开始
    // std::cout << lua_gettop(L) << std::endl;
    // 因为 fetch 第二个参数是options table，所以从2开始遍历
    // lua_next(L, 2) 返回0表示遍历结束
    // lua_next(L, 2) 返回1表示成功
    // lua_next 会先弹出一个top，然后再push一个key-value对，所以需要先push一个nil
    int v = lua_next(L, 2);
    // std::cout << "lua_next: " << v << std::endl;
    while (v != 0) {
        // std::cout << lua_gettop(L) << std::endl;
        // key在-2位置，value在-1位置
        std::string_view key = lua_tostring(L, -2); // 获取key
        // std::cout << "key: " << key << std::endl;
        if (key == "method") {
            if (lua_isstring(L, -1)) {
                std::string_view value = lua_tostring(L, -1); // 获取string类型的value
                // std::cout << "method: " << value << std::endl;
                if (value == "GET") {
                    curl_easy_setopt(curl, CURLOPT_HTTPGET, 1);
                } else if (value == "POST") {
                    curl_easy_setopt(curl, CURLOPT_POST, 1);
                } else {
                    luaL_error(L, "Unsupported method: %s", value.data());
                }
            }
        } else if (key == "headers") {
            if (lua_istable(L, -1)) {
                curl_slist *headers = nullptr;
                // 遍历headers table
                lua_pushnil(L); // 第一个key，nil表示从第一个元素开始
                while (lua_next(L, -2) != 0) {
                    std::string_view key = lua_tostring(L, -2);   // 获取key
                    std::string_view value = lua_tostring(L, -1); // 获取value
                    // CURLOPT_HEADER
                    std::string kv = std::format("%s: %s", key.data(), value.data());
                    headers = curl_slist_append(headers, kv.data());
                }
                curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
            } else {
                //
            }
        } else if (key == "body") {
            if (lua_isstring(L, -1)) {
                std::string_view value = lua_tostring(L, -1); // 获取string类型的value
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS, value.data());
            } else {
                // luaL_error(L, "Expected a string at index 2");
            }
        } else if (key == "timeout") {
            if (lua_isnumber(L, -1)) {
                int timeout = lua_tointeger(L, -1);
                curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
            } else {
                // luaL_error(L, "Expected a number at index 2");
            }
        } else if (key == "on_create") {
            // handle function
            if (lua_isfunction(L, -1)) {
                // 将 on_create 保存到 Lua 注册表中
                // lua_pushvalue(L, -1); // 拷贝 on_create 函数到栈顶
                // lua_setglobal(L, "saved_on_create"); // 将其设置为全局变量 saved_on_create
            } else {
                // luaL_error(L, "Expected a function at index 2");
            }
        } else if (key == "on_input") {
            // handle function
            if (lua_isfunction(L, -1)) {
            } else {
                // luaL_error(L, "Expected a function at index 2");
            }
        } else if (key == "on_once") {
            // handle function
            if (lua_isfunction(L, -1)) {
            } else {
                // luaL_error(L, "Expected a function at index 2");
            }
        } else if (key == "on_stream") {
            // handle function
            if (lua_isfunction(L, -1)) {
                // lua_getfield(L, -1, "on_stream");
            } else {
                // luaL_error(L, "Expected a function at index 2");
            }
        } else if (key == "on_error") {
            // handle function
            if (lua_isfunction(L, -1)) {
            } else {
                // luaL_error(L, "Expected a function at index 2");
            }
        } else if (key == "on_exit") {
            // handle function
            if (lua_isfunction(L, -1)) {
            } else {
                // luaL_error(L, "Expected a function at index 2");
            }
        }
        // 弹出value，保留key用于下一次迭代
        lua_pop(L, 1);
        v = lua_next(L, 2);
        // std::cout << "lua_next: " << v << std::endl;
    }

    // Set the callback function to write data to string
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, l_easy_writefunction);

    // Pass the string to store the response
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, L);

    lua_getfield(L, -1, "on_create");
    // push curl handle to stack
    lua_pushlightuserdata(L, curl);
    lua_call(L, 1, 0);

    CURLcode res = curl_easy_perform(curl);
    // Check for errors
    if (res != CURLE_OK) {
        std::cerr << "curl_easy_perform() failed: " << curl_easy_strerror(res) << std::endl;
        lua_getfield(L, -1, "on_error");
        // push curl handle to stack
        lua_pushlightuserdata(L, curl);
        lua_call(L, 1, 0);
    } else {
        std::cout << "Received " << readBuffer.size() << " bytes." << std::endl;
        // std::cout << "Data: " << readBuffer << std::endl;
        lua_getfield(L, -1, "on_once");
        // push curl handle to stack
        lua_pushlstring(L, readBuffer.data(), readBuffer.size());
        // lua_pushlightuserdata(L, curl);
        lua_call(L, 1, 0);
    }

    readBuffer.clear();
    curl_easy_cleanup(curl);

    curl = nullptr;
    lua_getfield(L, -1, "on_exit");
    // push curl handle to stack
    lua_pushlightuserdata(L, curl);
    lua_call(L, 1, 0);    

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

static const luaL_Reg libcurl_functions[] = {
    { "global_init", l_global_init },
    { "fetch", l_fetch },
    { "abort", l_abort },
    { "is_active", l_is_active },
    { NULL, NULL }
};

int luaopen_libcurl(lua_State *L) {
    lua_newtable(L);
    for (int i = 0; libcurl_functions[i].name != NULL; i++) {
        lua_pushcfunction(L, libcurl_functions[i].func);
        lua_setfield(L, -2, libcurl_functions[i].name);
    }
    return 1;
}
}
