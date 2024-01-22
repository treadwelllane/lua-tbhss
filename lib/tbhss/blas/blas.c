#include "lua.h"
#include "lauxlib.h"

#include "cblas.h"

#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <math.h>

#define TBHSS_BLAS_MATRIX_MT "tbhss_blas_matrix"

typedef struct {
  size_t rows;
  size_t columns;
  size_t doubles;
  double data[];
} tbhss_blas_matrix_t;

tbhss_blas_matrix_t *tbhss_blas_matrix_create (lua_State *L, size_t rows, size_t columns)
{
  size_t doubles = rows * columns;
  tbhss_blas_matrix_t *m0 = malloc(sizeof(tbhss_blas_matrix_t) + sizeof(double) * doubles);
  if (m0 == NULL)
    luaL_error(L, "Error in malloc during matrix create");
  tbhss_blas_matrix_t **m0p = (tbhss_blas_matrix_t **) lua_newuserdata(L, sizeof(tbhss_blas_matrix_t *));
  luaL_getmetatable(L, TBHSS_BLAS_MATRIX_MT); // tbl mat mt
  lua_setmetatable(L, -2); // tbl mat
  *m0p = m0;
  m0->rows = rows;
  m0->columns = columns;
  m0->doubles = doubles;
  return m0;
}

tbhss_blas_matrix_t **tbhss_blas_matrix_peekp (lua_State *L, int i)
{
  return (tbhss_blas_matrix_t **) luaL_checkudata(L, i, TBHSS_BLAS_MATRIX_MT);
}

tbhss_blas_matrix_t *tbhss_blas_matrix_peek (lua_State *L, int i)
{
  tbhss_blas_matrix_t **m0p = tbhss_blas_matrix_peekp(L, i);
  return *m0p;
}

size_t tbhss_blas_matrix_index (lua_State *L, tbhss_blas_matrix_t *m0, size_t row, size_t column)
{
  if (row > m0->rows || row < 1)
    luaL_error(L, "Matrix row index out of bounds");
  if (column > m0->columns || column < 1)
    luaL_error(L, "Matrix column index out of bounds");
  return (row - 1) * m0->columns + column - 1;
}

int tbhss_blas_matrix_copy (lua_State *L)
{
  lua_settop(L, 5);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  tbhss_blas_matrix_t *m1 = tbhss_blas_matrix_peek(L, 2);
  if (m0->columns != m1->columns)
    luaL_error(L, "Error in copy: can't copy between matrices with different column lengths");
  luaL_checktype(L, 3, LUA_TNUMBER);
  luaL_checktype(L, 4, LUA_TNUMBER);
  luaL_checktype(L, 5, LUA_TNUMBER);
  size_t rowstart = lua_tointeger(L, 3);
  size_t rowend = lua_tointeger(L, 4);
  size_t rowdest = lua_tointeger(L, 5);
  if (rowstart > rowend)
    luaL_error(L, "Error in copy: start row is greater than end row");
  if (rowdest + rowend - rowstart > m0->rows)
    luaL_error(L, "Error in copy: copying more rows than space available");
  size_t idxstart = tbhss_blas_matrix_index(L, m1, rowstart, 1);
  size_t idxend = tbhss_blas_matrix_index(L, m1, rowend, m1->columns);
  size_t idxdest = tbhss_blas_matrix_index(L, m0, rowdest, 1);
  memcpy(&m0->data[idxdest], &m1->data[idxstart], sizeof(double) * (idxend - idxstart + 1));
  return 0;
}

int tbhss_blas_matrix_shrink (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_matrix_t **m0p = tbhss_blas_matrix_peekp(L, 1);
  if ((*m0p)->doubles >= (*m0p)->rows * (*m0p)->columns) {
    (*m0p)->doubles = (*m0p)->rows * (*m0p)->columns;
    *m0p = realloc(*m0p, sizeof(tbhss_blas_matrix_t) + sizeof(double) * (*m0p)->doubles);
    if (*m0p == NULL)
      luaL_error(L, "Error in realloc during matrix shrink");
  }
  return 0;
}

int tbhss_blas_matrix_reshape (lua_State *L)
{
  lua_settop(L, 3);
  tbhss_blas_matrix_t **m0p = tbhss_blas_matrix_peekp(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  lua_Integer rows = lua_tointeger(L, 2);
  lua_Integer columns = lua_tointeger(L, 3);
  if (rows < 1)
    luaL_error(L, "Error in reshape: rows less than 1");
  if (columns < 1)
    luaL_error(L, "Error in reshape: columns less than 1");
  (*m0p)->rows = rows;
  (*m0p)->columns = columns;
  if (rows * columns > (*m0p)->doubles) {
    (*m0p)->doubles = rows * columns;
    *m0p = realloc(*m0p, sizeof(tbhss_blas_matrix_t) + sizeof(double) * (*m0p)->doubles);
    if (*m0p == NULL)
      luaL_error(L, "Error in realloc during matrix reshape");
  }
  return 0;
}

int tbhss_blas_matrix (lua_State *L)
{
  lua_settop(L, 2);
  luaL_checktype(L, 1, LUA_TNUMBER);
  luaL_checktype(L, 2, LUA_TNUMBER);
  size_t rows = lua_tointeger(L, 1);
  size_t columns = lua_tointeger(L, 2);
  tbhss_blas_matrix_create(L, rows, columns);
  return 1;
}

int tbhss_blas_matrix_gc (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  free(m0);
  return 0;
}

int tbhss_blas_matrix_get (lua_State *L)
{
  lua_settop(L, 3);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  lua_Integer column = lua_tointeger(L, 3);
  size_t idx = tbhss_blas_matrix_index(L, m0, row, column);
  lua_pushnumber(L, m0->data[idx]);
  return 1;
}

int tbhss_blas_matrix_set (lua_State *L)
{
  lua_settop(L, 4);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  luaL_checktype(L, 4, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  lua_Integer column = lua_tointeger(L, 3);
  lua_Number value = lua_tonumber(L, 4);
  size_t idx = tbhss_blas_matrix_index(L, m0, row, column);
  m0->data[idx] = value;
  return 0;
}

int tbhss_blas_matrix_radd (lua_State *L)
{
  lua_settop(L, 3);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  lua_Number add = lua_tonumber(L, 3);
  size_t idx = tbhss_blas_matrix_index(L, m0, row, 1);
  double x[1] = { add };
  cblas_daxpy(m0->columns, 1, x, 0, &m0->data[idx], 1);
  return 0;
}

int tbhss_blas_matrix_rmult (lua_State *L)
{
  lua_settop(L, 3);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  lua_Number scal = lua_tonumber(L, 3);
  size_t idx = tbhss_blas_matrix_index(L, m0, row, 1);
  cblas_dscal(m0->columns, scal, &m0->data[idx], 1);
  return 0;
}

int tbhss_blas_matrix_rmax (lua_State *L)
{
  lua_settop(L, 2);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  size_t idx = tbhss_blas_matrix_index(L, m0, row, 1);
  size_t maxcol = 1;
  double maxval = m0->data[idx];
  for (size_t i = 2; i <= m0->columns; i ++) {
    if (m0->data[idx + i - 1] > maxval) {
      maxcol = i;
      maxval = m0->data[idx + i - 1];
    }
  }
  lua_pushnumber(L, maxval);
  lua_pushinteger(L, maxcol);
  return 2;
}

int tbhss_blas_matrix_ramax (lua_State *L)
{
  lua_settop(L, 2);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  size_t idx = tbhss_blas_matrix_index(L, m0, row, 1);
  size_t idxval = cblas_idamax(m0->columns, &m0->data[idx], 1);
  lua_pushnumber(L, m0->data[idx + idxval]);
  lua_pushinteger(L, idxval);
  return 2;
}

int tbhss_blas_matrix_sum (lua_State *L)
{
  lua_settop(L, 3);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  tbhss_blas_matrix_t *m1 = tbhss_blas_matrix_peek(L, 2);
  luaL_checktype(L, 3, LUA_TNUMBER);
  if (m0->columns != m1->columns)
    luaL_error(L, "Error in sum: destination matrix columns don't match source matrix columns");
  lua_Integer rowdest = lua_tointeger(L, 3);
  size_t idxdest = tbhss_blas_matrix_index(L, m1, rowdest, 1);
  size_t idxsrc = tbhss_blas_matrix_index(L, m0, 1, 1);
  memcpy(&m1->data[idxdest], &m0->data[idxsrc], sizeof(double) * m1->columns);
  for (size_t i = 2; i <= m0->rows; i ++) {
    idxsrc = tbhss_blas_matrix_index(L, m0, i, 1);
    cblas_daxpy(m0->columns, 1, &m0->data[idxsrc], 1, &m1->data[idxdest], 1);
  }
  return 0;
}

int tbhss_blas_matrix_mmult (lua_State *L)
{
  lua_settop(L, 5);
  tbhss_blas_matrix_t *a = tbhss_blas_matrix_peek(L, 1);
  tbhss_blas_matrix_t *b = tbhss_blas_matrix_peek(L, 2);
  tbhss_blas_matrix_t *c = tbhss_blas_matrix_peek(L, 3);
  bool transpose_a = lua_toboolean(L, 4);
  bool transpose_b = lua_toboolean(L, 5);
  if (!transpose_a && !transpose_b) {
    if (a->columns != b->rows)
      luaL_error(L, "Error in mmult: columns of A don't match rows of B");
    if (a->rows != c->rows)
      luaL_error(L, "Error in mmult: rows of C don't match rows of A");
    if (b->columns != c->columns)
      luaL_error(L, "Error in mmult: columns of C don't match columns of B");
  } else if (transpose_a && !transpose_b) {
    if (a->rows != b->rows)
      luaL_error(L, "Error in mmult: rows of A don't match rows of B");
    if (a->columns != c->rows)
      luaL_error(L, "Error in mmult: rows of C don't match columns of A");
    if (b->columns != c->columns)
      luaL_error(L, "Error in mmult: columns of C don't match columns of B");
  } else if (!transpose_a && transpose_b) {
    if (a->columns != b->columns)
      luaL_error(L, "Error in mmult: columns of A don't match columns of B");
    if (a->rows != c->rows)
      luaL_error(L, "Error in mmult: rows of C don't match rows of A");
    if (b->rows != c->columns)
      luaL_error(L, "Error in mmult: columns of C don't match rows of B");
  } else if (transpose_a && transpose_b) {
    if (a->rows != b->columns)
      luaL_error(L, "Error in mmult: rows of A don't match columns of B");
    if (a->columns != c->columns)
      luaL_error(L, "Error in mmult: columns of C don't match columns of A");
    if (b->rows != c->rows)
      luaL_error(L, "Error in mmult: rows of C don't match rows of B");
  }
  cblas_dgemm(
    CblasRowMajor,
    transpose_a ? CblasTrans : CblasNoTrans,
    transpose_b ? CblasTrans : CblasNoTrans,
    c->rows,
    c->columns,
    a->columns,
    1.0,
    a->data,
    a->columns,
    b->data,
    b->columns,
    0.0,
    c->data,
    c->columns);
  return 0;
}

int tbhss_blas_matrix_magnitude (lua_State *L)
{
  lua_settop(L, 2);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  size_t idx = tbhss_blas_matrix_index(L, m0, row, 1);
  lua_pushnumber(L, cblas_dnrm2(m0->columns, &m0->data[idx], 1));
  return 1;
}

int tbhss_blas_matrix_shape (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  lua_pushinteger(L, m0->rows);
  lua_pushinteger(L, m0->columns);
  return 2;
}

int tbhss_blas_matrix_to_raw (lua_State *L)
{
  lua_settop(L, 1);
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_peek(L, 1);
  lua_pushlstring(L, (char *) m0->data, sizeof(double) * m0->rows * m0->columns);
  tbhss_blas_matrix_shape(L);
  return 3;
}

int tbhss_blas_matrix_from_raw (lua_State *L)
{
  lua_settop(L, 2);
  luaL_checktype(L, 1, LUA_TSTRING);
  luaL_checktype(L, 2, LUA_TNUMBER);
  size_t columns = lua_tointeger(L, 2);
  size_t size;
  const char *data = lua_tolstring(L, 1, &size);
  if (size % columns != 0)
    luaL_error(L, "Length of raw string is not a multiple of provided column length");
  size_t rows = size / columns;
  tbhss_blas_matrix_t *m0 = tbhss_blas_matrix_create(L, rows, columns);
  memcpy(m0->data, data, size);
  return 1;
}

luaL_Reg tbhss_blas_fns[] =
{
  { "matrix", tbhss_blas_matrix },
  { "from_raw", tbhss_blas_matrix_from_raw },
  { "to_raw", tbhss_blas_matrix_to_raw },
  { "get", tbhss_blas_matrix_get },
  { "set", tbhss_blas_matrix_set },
  { "shape", tbhss_blas_matrix_shape },
  { "magnitude", tbhss_blas_matrix_magnitude },
  { "mmult", tbhss_blas_matrix_mmult },
  { "rmult", tbhss_blas_matrix_rmult },
  { "radd", tbhss_blas_matrix_radd },
  { "copy", tbhss_blas_matrix_copy },
  { "sum", tbhss_blas_matrix_sum },
  { "rmax", tbhss_blas_matrix_rmax },
  { "ramax", tbhss_blas_matrix_ramax },
  { "reshape", tbhss_blas_matrix_reshape },
  { "shrink", tbhss_blas_matrix_shrink },
  { NULL, NULL }
};

int luaopen_tbhss_blas_blas (lua_State *L)
{
  lua_newtable(L); // t
  luaL_register(L, NULL, tbhss_blas_fns); // t
  luaL_newmetatable(L, TBHSS_BLAS_MATRIX_MT); // t mt
  lua_pushvalue(L, -1); // t mt mt
  lua_setfield(L, -3, "mt_matrix"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
