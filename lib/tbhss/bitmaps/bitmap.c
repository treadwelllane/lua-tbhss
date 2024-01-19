#include "lua.h"
#include "lauxlib.h"

#include <string.h>

#define TBHSS_BITMAP_MT "tbhss_bitmap"

typedef struct {
  lua_Integer bits;
  char data[];
} tbhss_bitmap;

int tbhss_bitmap_create (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TNUMBER);
  lua_Integer i = lua_tointeger(L, 1);
  lua_Integer chars = 1 + i / CHAR_BIT;
  tbhss_bitmap *bm = (tbhss_bitmap *)
    lua_newuserdata(L, sizeof(tbhss_bitmap) + sizeof(char) * chars);
  bm->bits = i;
  memset(&bm->data, 0, chars);
  luaL_getmetatable(L, TBHSS_BITMAP_MT);
  lua_setmetatable(L, -2);
  return 1;
}

int tbhss_bitmap_tostring (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TUSERDATA);
  tbhss_bitmap *bm = (tbhss_bitmap *) lua_touserdata(L, 1);
  luaL_Buffer buf;
  luaL_buffinit(L, &buf);
  luaL_addstring(&buf, "bitmap(");
  lua_pushinteger(L, bm->bits);
  luaL_addvalue(&buf);
  luaL_addstring(&buf, ") ");
  for (lua_Integer i = 0; i < bm->bits; i ++) {
    if ((bm->data[i / CHAR_BIT] >> (i % CHAR_BIT)) & 1) {
      luaL_addchar(&buf, '1');
    } else {
      luaL_addchar(&buf, '0');
    }
  }
  luaL_pushresult(&buf);
  return 1;
}

int tbhss_bitmap_hamming (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TUSERDATA);
  luaL_checktype(L, 2, LUA_TUSERDATA);
  tbhss_bitmap *bm0 = (tbhss_bitmap *) lua_touserdata(L, 1);
  tbhss_bitmap *bm1 = (tbhss_bitmap *) lua_touserdata(L, 2);
  lua_Integer bits = (bm0->bits <= bm1->bits ? bm0->bits : bm1->bits);
  lua_Integer bytes = bits / CHAR_BIT;
  if (bits % CHAR_BIT > 0)
    bytes ++;
  lua_Integer diff = 0;
  for (lua_Integer i = 0; i < bytes; i ++) {
    unsigned char r = bm0->data[i] ^ bm1->data[i];
    while (r) {
      r &= (r - 1);
      diff ++;
    }
  }
  lua_pushinteger(L, diff);
  return 1;
}

int tbhss_bitmap_set (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TUSERDATA);
  luaL_checktype(L, 2, LUA_TNUMBER);
  tbhss_bitmap *bm = (tbhss_bitmap *) lua_touserdata(L, 1);
  lua_Integer bit = lua_tointeger(L, 2);
  bit -= 1;
  if (bit > bm->bits)
    return 0;
  lua_Integer byteidx = bit / CHAR_BIT;
  lua_Integer bitidx = bit % CHAR_BIT;
  bm->data[byteidx] |= (1 << bitidx);
  return 0;
}

int tbhss_bitmap_unset (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TUSERDATA);
  luaL_checktype(L, 2, LUA_TNUMBER);
  tbhss_bitmap *bm = (tbhss_bitmap *) lua_touserdata(L, 1);
  lua_Integer bit = lua_tointeger(L, 2);
  bit -= 1;
  if (bit > bm->bits)
    return 0;
  lua_Integer byteidx = bit / CHAR_BIT;
  lua_Integer bitidx = bit % CHAR_BIT;
  char mask = ~(1 << bitidx);
  bm->data[byteidx] &= mask;
  return 0;
}

luaL_Reg tbhss_bitmap_mt_fns[] =
{
  { "set", tbhss_bitmap_set },
  { "unset", tbhss_bitmap_unset },
  { "hamming", tbhss_bitmap_hamming },
  { NULL, NULL }
};

luaL_Reg tbhss_bitmap_fns[] =
{
  { "create", tbhss_bitmap_create },
  { NULL, NULL }
};

int luaopen_tbhss_bitmaps_bitmap (lua_State *L)
{
  lua_newtable(L); // t
  luaL_register(L, NULL, tbhss_bitmap_fns); // t
  luaL_newmetatable(L, TBHSS_BITMAP_MT); // t mt
  lua_pushcfunction(L, tbhss_bitmap_tostring); // t mt fn
  lua_setfield(L, -2, "__tostring"); // t mt
  lua_newtable(L); // t mt idx
  luaL_register(L, NULL, tbhss_bitmap_mt_fns); // t mt idx
  lua_setfield(L, -2, "__index"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
