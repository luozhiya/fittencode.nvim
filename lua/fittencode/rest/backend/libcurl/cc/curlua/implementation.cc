#include <lua.h>
#include <vector>

extern "C" {

#include <lauxlib.h>

#include "implementation.h"

int curlua_global_init(lua_State *L) {
    CURLcode Code = curl_global_init(CURL_GLOBAL_ALL);
    lua_pushnumber(L, Code);
    if (Code != CURLE_OK) {
        lua_pushstring(L, curl_easy_strerror(Code));
        return 2;
    }
    return 1;
}

int curlua_global_cleanup(lua_State *L) {
    curl_global_cleanup();
    return 0;
}

int curlua_easy_init(lua_State *L) {
    CURL *Curl = curl_easy_init();
    if (Curl == NULL) {
        return 0;
    }
    lua_pushlightuserdata(L, Curl);
    return 1;
}

int curlua_easy_cleanup(lua_State *L) {
    CURL *Curl = (CURL *) lua_touserdata(L, 1);
    curl_easy_cleanup(Curl);
    return 0;
}

int curlua_easy_setopt(lua_State *L) {
    CURL *Curl = (CURL *) lua_touserdata(L, 1);
    CURLoption Option = (CURLoption) luaL_checkinteger(L, 2);
    CURLcode Code = CURLE_OK;
    if (lua_isstring(L, 3)) {
        char const *Value = luaL_checkstring(L, 3);
        Code = curl_easy_setopt(Curl, Option, Value);
    } else if (lua_isnumber(L, 3)) {
        long Value = luaL_checkinteger(L, 3);
        Code = curl_easy_setopt(Curl, Option, Value);
    } else if (lua_isuserdata(L, 3)) {
        void *Value = (void *) lua_touserdata(L, 3);
        Code = curl_easy_setopt(Curl, Option, Value);
    } else if (lua_isfunction(L, 3)) {
        if (Option == CURLOPT_WRITEFUNCTION) {
            // Value is a ffi `curl_write_callback` function
            // curl_write_callback Callback = [](char *Data, size_t Size, size_t Nmemb, void *Userp) {
            //     // Userp is a pointer to a Lua string
            //     lua_State *L = (lua_State *) Userp;
            //     luaL_checktype(L, -1, LUA_TSTRING);
            //     // lua_pushlstring(L, Data, Size * Nmemb);
            //     return Size * Nmemb;
            // };
            Code = curl_easy_setopt(Curl, Option, Callback);
        } else {
            Code = curl_easy_setopt(Curl, Option, lua_touserdata(L, 3));
        }
    } else if (lua_isnil(L, 3)) {
        Code = curl_easy_setopt(Curl, Option, NULL);
    } else if (lua_isboolean(L, 3)) {
        bool Value = lua_toboolean(L, 3);
        Code = curl_easy_setopt(Curl, Option, Value);
    } else {
        return luaL_error(L, "Invalid option value type");
    }
    lua_pushnumber(L, Code);
    if (Code != CURLE_OK) {
        lua_pushstring(L, curl_easy_strerror(Code));
        return 2;
    }
    return 1;
}

int curlua_easy_perform(lua_State *L) {
    CURL *Curl = (CURL *) lua_touserdata(L, 1);
    CURLcode Code = curl_easy_perform(Curl);
    lua_pushnumber(L, Code);
    if (Code != CURLE_OK) {
        lua_pushstring(L, curl_easy_strerror(Code));
        return 2;
    }
    return 1;
}
}
