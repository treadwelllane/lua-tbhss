#include "lua.h"
#include "lauxlib.h"

#include <string.h>
#include <stdlib.h>

#define TK_BITMAP_MT "santoku_bitmap"

typedef struct {
  lua_Integer bits;
  char data[];
} tk_bitmap_t;

tk_bitmap_t *tk_bitmap_peek (lua_State *L, int i)
{
  return *((tk_bitmap_t **) luaL_checkudata(L, i, TK_BITMAP_MT));
}

int tk_bitmap_destroy (lua_State *L)
{
  lua_settop(L, 1);
  tk_bitmap_t *bm0 = tk_bitmap_peek(L, 1);
  free(bm0);
  return 1;
}

int tk_bitmap_create (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TNUMBER);
  lua_Integer i = lua_tointeger(L, 1);
  lua_Integer chars = 1 + i / CHAR_BIT;
  tk_bitmap_t *bm0 = (tk_bitmap_t *) malloc(sizeof(tk_bitmap_t) + sizeof(char) * chars);
  if (bm0 == NULL)
    luaL_error(L, "Error in malloc during bitmap create");
  bm0->bits = i;
  memset(&bm0->data, 0, chars);
  tk_bitmap_t **bm0p = (tk_bitmap_t **) lua_newuserdata(L, sizeof(tk_bitmap_t *));
  *bm0p = bm0;
  luaL_getmetatable(L, TK_BITMAP_MT);
  lua_setmetatable(L, -2);
  return 1;
}

int tk_bitmap_size (lua_State *L)
{
  lua_settop(L, 1);
  tk_bitmap_t *bm0 = tk_bitmap_peek(L, 1);
  lua_pushinteger(L, bm0->bits);
  return 1;
}

int tk_bitmap_tostring (lua_State *L)
{
  lua_settop(L, 1);
  tk_bitmap_t *bm = tk_bitmap_peek(L, 1);
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

int tk_bitmap_hamming (lua_State *L)
{
  lua_settop(L, 2);
  tk_bitmap_t *bm0 = tk_bitmap_peek(L, 1);
  tk_bitmap_t *bm1 = tk_bitmap_peek(L, 2);
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

int tk_bitmap_get (lua_State *L)
{
  lua_settop(L, 2);
  tk_bitmap_t *bm = tk_bitmap_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer bit = lua_tointeger(L, 2);
  bit -= 1;
  if (bit > bm->bits || bit < 0)
    return 0;
  lua_Integer byteidx = bit / CHAR_BIT;
  lua_Integer bitidx = bit % CHAR_BIT;
  lua_pushboolean(L, bm->data[byteidx] & (1 << bitidx));
  return 1;
}

int tk_bitmap_set (lua_State *L)
{
  lua_settop(L, 2);
  tk_bitmap_t *bm = tk_bitmap_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer bit = lua_tointeger(L, 2);
  bit -= 1;
  if (bit > bm->bits)
    return 0;
  lua_Integer byteidx = bit / CHAR_BIT;
  lua_Integer bitidx = bit % CHAR_BIT;
  bm->data[byteidx] |= (1 << bitidx);
  return 0;
}

int tk_bitmap_unset (lua_State *L)
{
  lua_settop(L, 2);
  luaL_checktype(L, 2, LUA_TNUMBER);
  tk_bitmap_t *bm = tk_bitmap_peek(L, 1);
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

luaL_Reg tk_bitmap_fns[] =
{
  { "create", tk_bitmap_create },
  { "destroy", tk_bitmap_destroy },
  { "set", tk_bitmap_set },
  { "get", tk_bitmap_get },
  { "size", tk_bitmap_size },
  { "unset", tk_bitmap_unset },
  { "hamming", tk_bitmap_hamming },
  { NULL, NULL }
};

int luaopen_santoku_bitmap (lua_State *L)
{
  lua_newtable(L); // t
  luaL_register(L, NULL, tk_bitmap_fns); // t
  luaL_newmetatable(L, TK_BITMAP_MT); // t mt
  lua_pushcfunction(L, tk_bitmap_tostring); // t mt fn
  lua_setfield(L, -2, "__tostring"); // t mt
  lua_pushcfunction(L, tk_bitmap_destroy); // t mt fn
  lua_setfield(L, -2, "__gc"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
