#include "lua.h"
#include "lauxlib.h"

#include "cblas.h"
#include <string.h>
#include <stdlib.h>
#include <math.h>

#define TBHSS_BLAS_VECTOR_MT "tbhss_blas_vector"

typedef struct {
  size_t size;
  double data[];
} tbhss_blas_vector_t;

tbhss_blas_vector_t *tbhss_blas_vector_create (lua_State *L, size_t size)
{
  tbhss_blas_vector_t *vec = malloc(sizeof(tbhss_blas_vector_t) + sizeof(double) * size);
  tbhss_blas_vector_t **vecp = (tbhss_blas_vector_t **) lua_newuserdata(L, sizeof(tbhss_blas_vector_t *));
  luaL_getmetatable(L, TBHSS_BLAS_VECTOR_MT); // tbl vec mt
  lua_setmetatable(L, -2); // tbl vec
  *vecp = vec;
  vec->size = size;
  return vec;
}

tbhss_blas_vector_t *tbhss_blas_vector_peek (lua_State *L, int i)
{
  tbhss_blas_vector_t **vp = (tbhss_blas_vector_t **) luaL_checkudata(L, i, TBHSS_BLAS_VECTOR_MT);
  return *vp;
}

int tbhss_blas_vector_gc (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, 1);
  free(v0);
  return 0;
}

int tbhss_blas_vector (lua_State *L)
{
  lua_settop(L, 1);
  if (lua_type(L, 1) == LUA_TNUMBER) {
    lua_Integer size = lua_tointeger(L, 1);
    if (size < 0)
      luaL_error(L, "can't create a vector with negative size");
    tbhss_blas_vector_create(L, size);
    return 1;
  } else {
    luaL_checktype(L, 1, LUA_TTABLE); // tbl
    size_t size = lua_objlen(L, 1);
    tbhss_blas_vector_t *vec = tbhss_blas_vector_create(L, size);
    for (size_t i = 1; i <= size; i ++) {
      lua_pushinteger(L, i); // tbl vec i
      lua_gettable(L, -3); // tbl vec d
      luaL_checktype(L, -1, LUA_TNUMBER);
      vec->data[i - 1] = lua_tonumber(L, -1);
      lua_pop(L, 1); // tbl vec
    }
    return 1;
  }
}

int tbhss_blas_average (lua_State *L)
{
  lua_settop(L, 1);
  luaL_checktype(L, 1, LUA_TTABLE); // tbl
  size_t nvecs = lua_objlen(L, 1);
  if (nvecs < 1)
    luaL_error(L, "cant take an average of fewer than 1 vector");
  lua_pushinteger(L, 1); // tbl i
  lua_gettable(L, -2); // tbl vec
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, -1);
  size_t dims = v0->size;
  lua_pop(L, 1); // tbl
  tbhss_blas_vector_t *out = tbhss_blas_vector_create(L, dims);
  cblas_dcopy(v0->size, v0->data, 1, out->data, 1);
  for (size_t i = 2; i <= nvecs; i ++) {
    lua_pushinteger(L, i); // tbl vec i
    lua_gettable(L, -3); // tbl vec vec
    tbhss_blas_vector_t *v1 = tbhss_blas_vector_peek(L, -1);
    cblas_daxpy(out->size, 1, v1->data, 1, out->data, 1);
    lua_pop(L, 1); // tbl vec
  }
  cblas_dscal(out->size, 1 / (double) nvecs, out->data, 1);
  return 1;
}

int tbhss_blas_vector_dot (lua_State *L)
{
  lua_settop(L, 2);
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, 1);
  tbhss_blas_vector_t *v1 = tbhss_blas_vector_peek(L, 2);

  if (v0->size != v1->size)
    luaL_error(L, "vectors are not the same size");

  lua_pushnumber(L, cblas_ddot(v0->size, v0->data, 1, v1->data, 1));
  return 1;
}

int tbhss_blas_vector_normalize (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, 1);
  double m = sqrt(cblas_ddot(v0->size, v0->data, 1, v0->data, 1));
  cblas_dscal(v0->size, 1 / m, v0->data, 1);
  return 0;
}

int tbhss_blas_vector_get (lua_State *L)
{
  lua_settop(L, 2);
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer i = lua_tointeger(L, 2);
  if (v0->size < i)
    lua_pushnil(L);
  else
    lua_pushnumber(L, v0->data[i - 1]);
  return 1;
}

int tbhss_blas_vector_set (lua_State *L)
{
  lua_settop(L, 3);
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  lua_Integer i = lua_tointeger(L, 2);
  lua_Number v = lua_tonumber(L, 3);
  if (v0->size < i)
    luaL_error(L, "vector index out of bounds during set");
  v0->data[i - 1] = v;
  return 0;
}

int tbhss_blas_vector_tostring (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, 1);
  luaL_Buffer buf;
  luaL_buffinit(L, &buf);
  luaL_addstring(&buf, "vector(");
  lua_pushinteger(L, v0->size);
  luaL_addvalue(&buf);
  luaL_addstring(&buf, ") ");
  for (lua_Integer i = 0; i < v0->size; i ++) {
    lua_pushnumber(L, v0->data[i]);
    luaL_addvalue(&buf);
    luaL_addstring(&buf, " ");
  }
  luaL_pushresult(&buf);
  return 1;
}

int tbhss_blas_vector_raw (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_vector_t *v0 = tbhss_blas_vector_peek(L, 1);
  lua_pushlstring(L, (char *) v0->data, v0->size * sizeof(double));
  return 1;
}

int tbhss_blas_from_raw (lua_State *L)
{
  lua_settop(L, 1);
  luaL_checktype(L, 1, LUA_TSTRING);
  size_t size;
  const char *data = lua_tolstring(L, 1, &size);
  size_t doubles = size / sizeof(double);
  tbhss_blas_vector_t *out = tbhss_blas_vector_create(L, doubles);
  memcpy(out->data, data, size);
  return 1;
}

luaL_Reg tbhss_blas_vector_mt_fns[] =
{
  { "dot", tbhss_blas_vector_dot },
  { "set", tbhss_blas_vector_set },
  { "get", tbhss_blas_vector_get },
  { "raw", tbhss_blas_vector_raw },
  { "normalize", tbhss_blas_vector_normalize },
  { NULL, NULL }
};

luaL_Reg tbhss_blas_mt_fns[] =
{
  { "vector", tbhss_blas_vector },
  { "from_raw", tbhss_blas_from_raw },
  { "average", tbhss_blas_average },
  { NULL, NULL }
};

int luaopen_tbhss_blas (lua_State *L)
{
  lua_newtable(L); // t
  luaL_register(L, NULL, tbhss_blas_mt_fns); // t
  luaL_newmetatable(L, TBHSS_BLAS_VECTOR_MT); // t mt
  lua_pushcfunction(L, tbhss_blas_vector_tostring); // t mt fn
  lua_setfield(L, -2, "__tostring"); // t mt
  lua_pushcfunction(L, tbhss_blas_vector_gc); // t mt fn
  lua_setfield(L, -2, "__gc"); // t mt
  lua_newtable(L); // t mt idx
  luaL_register(L, NULL, tbhss_blas_vector_mt_fns); // t mt idx
  lua_setfield(L, -2, "__index"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
