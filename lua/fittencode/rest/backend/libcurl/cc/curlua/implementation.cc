extern "C" {

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

}
