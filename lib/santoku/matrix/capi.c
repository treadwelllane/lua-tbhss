#include "lua.h"
#include "lauxlib.h"

#include "cblas.h"

#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <math.h>

#define TK_MATRIX_MT "santoku_matrix"

typedef struct {
  size_t rows;
  size_t columns;
  size_t doubles;
  double data[];
} tk_matrix_t;

tk_matrix_t *tk_matrix_create (lua_State *L, size_t rows, size_t columns)
{
  size_t doubles = rows * columns;
  tk_matrix_t *m0 = malloc(sizeof(tk_matrix_t) + sizeof(double) * doubles);
  if (m0 == NULL)
    luaL_error(L, "Error in malloc during matrix create");
  m0->rows = rows;
  m0->columns = columns;
  m0->doubles = doubles;
  tk_matrix_t **m0p = (tk_matrix_t **) lua_newuserdata(L, sizeof(tk_matrix_t *));
  luaL_getmetatable(L, TK_MATRIX_MT); // tbl mat mt
  lua_setmetatable(L, -2); // tbl mat
  *m0p = m0;
  return m0;
}

tk_matrix_t **tk_matrix_peekp (lua_State *L, int i)
{
  return (tk_matrix_t **) luaL_checkudata(L, i, TK_MATRIX_MT);
}

tk_matrix_t *tk_matrix_peek (lua_State *L, int i)
{
  tk_matrix_t **m0p = tk_matrix_peekp(L, i);
  return *m0p;
}

size_t tk_matrix_index (lua_State *L, tk_matrix_t *m0, size_t row, size_t column)
{
  if (row > m0->rows || row < 1)
    luaL_error(L, "Matrix row index out of bounds");
  if (column > m0->columns || column < 1)
    luaL_error(L, "Matrix column index out of bounds");
  return (row - 1) * m0->columns + column - 1;
}

int tk_matrix_copy (lua_State *L)
{
  lua_settop(L, 5);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  tk_matrix_t *m1 = tk_matrix_peek(L, 2);
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
  size_t idxstart = tk_matrix_index(L, m1, rowstart, 1);
  size_t idxend = tk_matrix_index(L, m1, rowend, m1->columns);
  size_t idxdest = tk_matrix_index(L, m0, rowdest, 1);
  memcpy(&m0->data[idxdest], &m1->data[idxstart], sizeof(double) * (idxend - idxstart + 1));
  return 0;
}

int tk_matrix_shrink (lua_State *L)
{
  lua_settop(L, 1);
  tk_matrix_t **m0p = tk_matrix_peekp(L, 1);
  if ((*m0p)->doubles >= (*m0p)->rows * (*m0p)->columns) {
    (*m0p)->doubles = (*m0p)->rows * (*m0p)->columns;
    *m0p = realloc(*m0p, sizeof(tk_matrix_t) + sizeof(double) * (*m0p)->doubles);
    if (*m0p == NULL)
      luaL_error(L, "Error in realloc during matrix shrink");
  }
  return 0;
}

int tk_matrix_reshape (lua_State *L)
{
  lua_settop(L, 3);
  tk_matrix_t **m0p = tk_matrix_peekp(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  lua_Integer rows = lua_tointeger(L, 2);
  lua_Integer columns = lua_tointeger(L, 3);
  if (rows < 0)
    luaL_error(L, "Error in reshape: rows less than 0");
  if (columns < 0)
    luaL_error(L, "Error in reshape: columns less than 0");
  (*m0p)->rows = rows;
  (*m0p)->columns = columns;
  if (rows * columns > (*m0p)->doubles) {
    (*m0p)->doubles = rows * columns;
    *m0p = realloc(*m0p, sizeof(tk_matrix_t) + sizeof(double) * (*m0p)->doubles);
    if (*m0p == NULL)
      luaL_error(L, "Error in realloc during matrix reshape");
  }
  return 0;
}

int tk_matrix (lua_State *L)
{
  lua_settop(L, 2);
  luaL_checktype(L, 1, LUA_TNUMBER);
  luaL_checktype(L, 2, LUA_TNUMBER);
  size_t rows = lua_tointeger(L, 1);
  size_t columns = lua_tointeger(L, 2);
  tk_matrix_create(L, rows, columns);
  return 1;
}

int tk_matrix_gc (lua_State *L)
{
  lua_settop(L, 1);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  free(m0);
  return 0;
}

int tk_matrix_get (lua_State *L)
{
  lua_settop(L, 3);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  lua_Integer column = lua_tointeger(L, 3);
  size_t idx = tk_matrix_index(L, m0, row, column);
  lua_pushnumber(L, m0->data[idx]);
  return 1;
}

int tk_matrix_set (lua_State *L)
{
  lua_settop(L, 4);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  luaL_checktype(L, 4, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  lua_Integer column = lua_tointeger(L, 3);
  lua_Number value = lua_tonumber(L, 4);
  size_t idx = tk_matrix_index(L, m0, row, column);
  m0->data[idx] = value;
  return 0;
}

int tk_matrix_radd (lua_State *L)
{
  lua_settop(L, 5);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  luaL_checktype(L, 4, LUA_TNUMBER);
  lua_Integer rowstart = lua_tointeger(L, 2);
  lua_Integer rowend = lua_tointeger(L, 3);
  lua_Number add = lua_tonumber(L, 4);
  if (rowstart > rowend)
    luaL_error(L, "Error in radd: start row is greater than end row");
  size_t idxstart = tk_matrix_index(L, m0, rowstart, 1);
  size_t idxend = tk_matrix_index(L, m0, rowend, m0->columns);
  double x[1] = { add };
  cblas_daxpy(idxend - idxstart + 1, 1, x, 0, &m0->data[idxstart], 1);
  return 0;
}

int tk_matrix_rmult (lua_State *L)
{
  lua_settop(L, 4);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  luaL_checktype(L, 4, LUA_TNUMBER);
  lua_Integer rowstart = lua_tointeger(L, 2);
  lua_Integer rowend = lua_tointeger(L, 3);
  lua_Number scal = lua_tonumber(L, 4);
  if (rowstart > rowend)
    luaL_error(L, "Error in rmult: start row is greater than end row");
  size_t idxstart = tk_matrix_index(L, m0, rowstart, 1);
  size_t idxend = tk_matrix_index(L, m0, rowend, m0->columns);
  cblas_dscal(idxend - idxstart + 1, scal, &m0->data[idxstart], 1);
  return 0;
}

int tk_matrix_exp (lua_State *L)
{
  lua_settop(L, 4);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  luaL_checktype(L, 4, LUA_TNUMBER);
  lua_Integer rowstart = lua_tointeger(L, 2);
  lua_Integer rowend = lua_tointeger(L, 3);
  lua_Number exp = lua_tonumber(L, 4);
  if (rowstart > rowend)
    luaL_error(L, "Error in rmult: start row is greater than end row");
  size_t idxstart = tk_matrix_index(L, m0, rowstart, 1);
  size_t idxend = tk_matrix_index(L, m0, rowend, m0->columns);
  for (size_t i = idxstart; i <= idxend; i ++)
    m0->data[i] = pow(m0->data[i], exp);
  return 0;
}

int tk_matrix_rmin (lua_State *L)
{
  lua_settop(L, 2);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  size_t idx = tk_matrix_index(L, m0, row, 1);
  size_t mincol = 1;
  double minval = m0->data[idx];
  for (size_t i = 2; i <= m0->columns; i ++) {
    if (m0->data[idx + i - 1] < minval) {
      mincol = i;
      minval = m0->data[idx + i - 1];
    }
  }
  lua_pushnumber(L, minval);
  lua_pushinteger(L, mincol);
  return 2;
}

int tk_matrix_rmax (lua_State *L)
{
  lua_settop(L, 2);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  size_t idx = tk_matrix_index(L, m0, row, 1);
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

int tk_matrix_ramax (lua_State *L)
{
  lua_settop(L, 2);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  size_t idx = tk_matrix_index(L, m0, row, 1);
  size_t idxval = cblas_idamax(m0->columns, &m0->data[idx], 1);
  lua_pushnumber(L, m0->data[idx + idxval]);
  lua_pushinteger(L, idxval);
  return 2;
}

int tk_matrix_sum (lua_State *L)
{
  lua_settop(L, 3);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  size_t rowstart = lua_tointeger(L, 2);
  size_t rowend = lua_tointeger(L, 3);
  if (rowstart > rowend)
    luaL_error(L, "Error in sum: start row is greater than end row");
  size_t idxstart = tk_matrix_index(L, m0, rowstart, 1);
  size_t idxend = tk_matrix_index(L, m0, rowend, m0->columns);
  double sum = 0;
  for (size_t i = idxstart; i <= idxend; i ++)
    sum += m0->data[i];
  lua_pushnumber(L, sum);
  return 1;
}

int tk_matrix_sums (lua_State *L)
{
  lua_settop(L, 3);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  tk_matrix_t *m1 = tk_matrix_peek(L, 2);
  luaL_checktype(L, 3, LUA_TNUMBER);
  if (m0->columns != m1->columns)
    luaL_error(L, "Error in sums: destination matrix columns don't match source matrix columns");
  lua_Integer rowdest = lua_tointeger(L, 3);
  size_t idxdest = tk_matrix_index(L, m1, rowdest, 1);
  size_t idxsrc = tk_matrix_index(L, m0, 1, 1);
  memcpy(&m1->data[idxdest], &m0->data[idxsrc], sizeof(double) * m1->columns);
  for (size_t i = 2; i <= m0->rows; i ++) {
    idxsrc = tk_matrix_index(L, m0, i, 1);
    cblas_daxpy(m0->columns, 1, &m0->data[idxsrc], 1, &m1->data[idxdest], 1);
  }
  return 0;
}

int tk_matrix_mmult (lua_State *L)
{
  lua_settop(L, 5);
  tk_matrix_t *a = tk_matrix_peek(L, 1);
  tk_matrix_t *b = tk_matrix_peek(L, 2);
  tk_matrix_t *c = tk_matrix_peek(L, 3);
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

int tk_matrix_magnitude (lua_State *L)
{
  lua_settop(L, 2);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  lua_Integer row = lua_tointeger(L, 2);
  size_t idx = tk_matrix_index(L, m0, row, 1);
  lua_pushnumber(L, cblas_dnrm2(m0->columns, &m0->data[idx], 1));
  return 1;
}

int tk_matrix_rows (lua_State *L)
{
  lua_settop(L, 1);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  lua_pushinteger(L, m0->rows);
  return 1;
}

int tk_matrix_columns (lua_State *L)
{
  lua_settop(L, 1);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  lua_pushinteger(L, m0->columns);
  return 1;
}

int tk_matrix_shape (lua_State *L)
{
  lua_settop(L, 1);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  lua_pushinteger(L, m0->rows);
  lua_pushinteger(L, m0->columns);
  return 2;
}

int tk_matrix_extend_raw (lua_State *L)
{
  lua_settop(L, 2);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TSTRING);
  size_t size;
  const char *data = lua_tolstring(L, 2, &size);
  if (size % sizeof(double) != 0)
    luaL_error(L, "Length of raw string is not a multiple of sizeof(double)");
  size_t doubles = size / sizeof(double);
  if (doubles % m0->columns != 0)
    luaL_error(L, "Length of raw string is not a multiple of matrix columns");
  size_t extend_rows = doubles / m0->columns;
  size_t extend_rowstart = m0->rows + 1;
  size_t newrows = m0->rows + extend_rows;
  lua_pop(L, 1);
  lua_pushinteger(L, newrows);
  lua_pushinteger(L, m0->columns);
  tk_matrix_reshape(L);
  m0 = tk_matrix_peek(L, 1);
  size_t idxextend = tk_matrix_index(L, m0, extend_rowstart, 1);
  memcpy(&m0->data[idxextend], data, size);
  return 0;
}

int tk_matrix_to_raw (lua_State *L)
{
  lua_settop(L, 3);
  tk_matrix_t *m0 = tk_matrix_peek(L, 1);
  luaL_checktype(L, 2, LUA_TNUMBER);
  luaL_checktype(L, 3, LUA_TNUMBER);
  size_t rowstart = lua_tointeger(L, 2);
  size_t rowend = lua_tointeger(L, 3);
  if (rowstart > rowend)
    luaL_error(L, "Error in copy: start row is greater than end row");
  size_t idxstart = tk_matrix_index(L, m0, rowstart, 1);
  size_t idxend = tk_matrix_index(L, m0, rowend, m0->columns);
  lua_pushlstring(L, (char *) &m0->data[idxstart], sizeof(double) * (idxend - idxstart + 1));
  return 1;
}

int tk_matrix_from_raw (lua_State *L)
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
  tk_matrix_t *m0 = tk_matrix_create(L, rows, columns);
  memcpy(m0->data, data, size);
  return 1;
}

luaL_Reg tk_matrix_fns[] =
{
  { "matrix", tk_matrix },
  { "from_raw", tk_matrix_from_raw },
  { "to_raw", tk_matrix_to_raw },
  { "extend_raw", tk_matrix_extend_raw },
  { "get", tk_matrix_get },
  { "set", tk_matrix_set },
  { "shape", tk_matrix_shape },
  { "rows", tk_matrix_rows },
  { "columns", tk_matrix_columns },
  { "magnitude", tk_matrix_magnitude },
  { "mmult", tk_matrix_mmult },
  { "rmult", tk_matrix_rmult },
  { "radd", tk_matrix_radd },
  { "copy", tk_matrix_copy },
  { "sums", tk_matrix_sums },
  { "sum", tk_matrix_sum },
  { "exp", tk_matrix_exp },
  { "rmax", tk_matrix_rmax },
  { "rmin", tk_matrix_rmin },
  { "ramax", tk_matrix_ramax },
  { "reshape", tk_matrix_reshape },
  { "shrink", tk_matrix_shrink },
  { NULL, NULL }
};

int luaopen_santoku_matrix_capi (lua_State *L)
{
  lua_newtable(L); // t
  luaL_register(L, NULL, tk_matrix_fns); // t
  luaL_newmetatable(L, TK_MATRIX_MT); // t mt
  lua_pushcfunction(L, tk_matrix_gc);
  lua_setfield(L, -2, "__gc");
  lua_pushvalue(L, -1); // t mt mt
  lua_setfield(L, -3, "mt_matrix"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
