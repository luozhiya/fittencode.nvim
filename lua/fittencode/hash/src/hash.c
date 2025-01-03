#include <lua.h>
#include <lauxlib.h>

#include "md5.h"

// Lua wrapper for MD5 hashing
static int l_md5(lua_State *L) {
    const char *input = luaL_checkstring(L, 1);
    uint8_t output[16];
    char md5string[33];

    md5_hash(input, output);

    for (int i = 0; i < 16; i++)
        sprintf(&md5string[i * 2], "%02x", output[i]);

    lua_pushstring(L, md5string);
    return 1;
}

// Register the function in Lua
static const luaL_Reg hashfunctions[] = {
    {"md5", l_md5},
    {NULL, NULL}
};

int luaopen_hash(lua_State *L) {
    lua_newtable(L);
    for (int i = 0; hashfunctions[i].name != NULL; i++) {
        lua_pushcfunction(L, hashfunctions[i].func);
        lua_setfield(L, -2, hashfunctions[i].name);
    }
    return 1;
}
