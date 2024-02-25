#include "lua.h"
#include "lauxlib.h"

#include "roaring.c"

#define TK_BITMAP_MT "santoku_bitmap"

roaring_bitmap_t *tk_bitmap_peek (lua_State *L, int i)
{
  return *((roaring_bitmap_t **) luaL_checkudata(L, i, TK_BITMAP_MT));
}

int tk_bitmap_destroy (lua_State *L)
{
  lua_settop(L, 1);
  roaring_bitmap_t *bm = tk_bitmap_peek(L, 1);
  roaring_bitmap_free(bm);
  return 1;
}

int tk_bitmap_create (lua_State *L)
{
  lua_settop(L, 0);
  roaring_bitmap_t *bm = roaring_bitmap_create();
  if (bm == NULL)
    luaL_error(L, "memory error creating bitmap");
  roaring_bitmap_t **bmp = (roaring_bitmap_t **) lua_newuserdata(L, sizeof(roaring_bitmap_t *));
  *bmp = bm;
  luaL_getmetatable(L, TK_BITMAP_MT);
  lua_setmetatable(L, -2);
  return 1;
}

int tk_bitmap_get (lua_State *L)
{
  lua_settop(L, 2);
  roaring_bitmap_t *bm = tk_bitmap_peek(L, 1);
  lua_Integer bit = luaL_checkinteger(L, 2);
  bit --;
  if (bit < 0)
    luaL_error(L, "bit index must be greater than zero");
  lua_pushboolean(L, roaring_bitmap_contains(bm, bit));
  return 1;
}

int tk_bitmap_set (lua_State *L)
{
  lua_settop(L, 3);
  roaring_bitmap_t *bm = tk_bitmap_peek(L, 1);
  lua_Integer bit = luaL_checkinteger(L, 2);
  bit --;
  if (bit < 0)
    luaL_error(L, "bit index must be greater than zero");
  if (lua_type(L, 3) != LUA_TNIL) {
    lua_Integer until = luaL_checkinteger(L, 3);
    until --;
    if (until < bit)
      luaL_error(L, "end index must be greater than start index");
    roaring_bitmap_add_range_closed(bm, bit, until);
  } else {
    roaring_bitmap_add(bm, bit);
  }
  return 0;
}

int tk_bitmap_unset (lua_State *L)
{
  lua_settop(L, 2);
  roaring_bitmap_t *bm = tk_bitmap_peek(L, 1);
  lua_Integer bit = luaL_checkinteger(L, 2);
  bit --;
  if (bit < 0)
    luaL_error(L, "bit index must be greater than zero");
  roaring_bitmap_remove(bm, bit);
  return 0;
}

int tk_bitmap_cardinality (lua_State *L)
{
  lua_settop(L, 1);
  roaring_bitmap_t *bm = tk_bitmap_peek(L, 1);
  lua_pushinteger(L, roaring_bitmap_get_cardinality(bm));
  return 1;
}

int tk_bitmap_clear (lua_State *L)
{
  lua_settop(L, 1);
  roaring_bitmap_t *bm = tk_bitmap_peek(L, 1);
  roaring_bitmap_clear(bm);
  return 0;
}

int tk_bitmap_and (lua_State *L)
{
  lua_settop(L, 2);
  roaring_bitmap_t *bm0 = tk_bitmap_peek(L, 1);
  roaring_bitmap_t *bm1 = tk_bitmap_peek(L, 2);
  roaring_bitmap_and_inplace(bm0, bm1);
  return 0;
}

int tk_bitmap_or (lua_State *L)
{
  lua_settop(L, 2);
  roaring_bitmap_t *bm0 = tk_bitmap_peek(L, 1);
  roaring_bitmap_t *bm1 = tk_bitmap_peek(L, 2);
  roaring_bitmap_or_inplace(bm0, bm1);
  return 0;
}

int tk_bitmap_xor (lua_State *L)
{
  lua_settop(L, 2);
  roaring_bitmap_t *bm0 = tk_bitmap_peek(L, 1);
  roaring_bitmap_t *bm1 = tk_bitmap_peek(L, 2);
  roaring_bitmap_xor_inplace(bm0, bm1);
  return 0;
}

luaL_Reg tk_bitmap_fns[] =
{
  { "create", tk_bitmap_create },
  { "destroy", tk_bitmap_destroy },
  { "set", tk_bitmap_set },
  { "get", tk_bitmap_get },
  { "unset", tk_bitmap_unset },
  { "cardinality", tk_bitmap_cardinality },
  { "clear", tk_bitmap_clear },
  { "and", tk_bitmap_and },
  { "or", tk_bitmap_or },
  { "xor", tk_bitmap_xor },
  { NULL, NULL }
};

int luaopen_santoku_bitmap_capi (lua_State *L)
{
  lua_newtable(L); // t
  luaL_register(L, NULL, tk_bitmap_fns); // t
  luaL_newmetatable(L, TK_BITMAP_MT); // t mt
  lua_pushcfunction(L, tk_bitmap_destroy); // t mt fn
  lua_setfield(L, -2, "__gc"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
