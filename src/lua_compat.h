// Include before conf.h. conf.h is written for Lua 5.1 (and LuaJIT), and
// builds with 5.4 except for one function 5.2 renamed: lua_objlen, now
// lua_rawlen. This maps it, so conf.h itself stays as it is upstream.
#ifndef LUA_COMPAT_H
#define LUA_COMPAT_H

#include <lua.h>

#if LUA_VERSION_NUM >= 502 && !defined(lua_objlen)
#define lua_objlen(L, i) lua_rawlen(L, (i))
#endif

#endif
