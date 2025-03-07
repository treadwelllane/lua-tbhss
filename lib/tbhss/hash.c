#include "lua.h"
#include "lauxlib.h"
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define BYTES (sizeof(uint32_t))
#define BITS (BYTES * CHAR_BIT)

static inline double tk_lua_optposdouble (lua_State *L, int i, double def)
{
  if (lua_type(L, i) < 1)
    return def;
  lua_Number l = luaL_checknumber(L, i);
  if (l < 0)
    luaL_error(L, "value can't be negative");
  return (double) l;
}

static inline double tk_lua_checkposdouble (lua_State *L, int i)
{
  lua_Number l = luaL_checknumber(L, i);
  if (l < 0)
    luaL_error(L, "value can't be negative");
  return (double) l;
}

static inline unsigned int tk_lua_len (lua_State *L, int i)
{
  size_t l = lua_objlen(L, i);
  return l < 0 ? 0 : (unsigned int) l;
}

static inline unsigned int tk_lua_checkunsigned (lua_State *L, int i)
{
  lua_Integer l = luaL_checkinteger(L, i);
  if (l < 0)
    luaL_error(L, "value can't be negative");
  if (l > UINT_MAX)
    luaL_error(L, "value is too large");
  return (unsigned int) l;
}

static inline unsigned int tk_lua_optunsigned (lua_State *L, int i, unsigned int def)
{
  if (lua_type(L, i) < 1)
    return def;
  return tk_lua_checkunsigned(L, i);
}

static inline void tk_lua_register (lua_State *L, luaL_Reg *regs, int nup)
{
  while (true) {
    if ((*regs).name == NULL)
      break;
    for (int i = 0; i < nup; i ++)
      lua_pushvalue(L, -nup); // t upsa upsb
    lua_pushcclosure(L, (*regs).func, nup); // t upsa fn
    lua_setfield(L, -nup - 2, (*regs).name); // t
    regs ++;
  }
  lua_pop(L, nup);
}

static inline uint32_t rotl32 (uint32_t x, int8_t r)
{
  return (x << r) | (x >> (32 - r));
}

static inline uint32_t fmix32 (uint32_t h)
{
  h ^= h >> 16;
  h *= 0x85ebca6b;
  h ^= h >> 13;
  h *= 0xc2b2ae35;
  h ^= h >> 16;
  return h;
}

static inline uint32_t murmur32 (const void *key, int len, uint32_t seed)
{
  const uint8_t * data = (const uint8_t*)key;
  const int nblocks = len / 4;
  uint32_t h1 = seed;
  const uint32_t c1 = 0xcc9e2d51;
  const uint32_t c2 = 0x1b873593;
  const uint32_t * blocks = (const uint32_t *)(data + nblocks*4);
  for(int i = -nblocks; i; i++)
  {
    uint32_t k1 = blocks[i];
    k1 *= c1;
    k1 = rotl32(k1,15);
    k1 *= c2;
    h1 ^= k1;
    h1 = rotl32(h1,13);
    h1 = h1*5+0xe6546b64;
  }
  const uint8_t * tail = (const uint8_t*)(data + nblocks*4);
  uint32_t k1 = 0;
  switch(len & 3)
  {
  case 3: k1 ^= tail[2] << 16;
  case 2: k1 ^= tail[1] << 8;
  case 1: k1 ^= tail[0];
          k1 *= c1; k1 = rotl32(k1,15); k1 *= c2; h1 ^= k1;
  };
  h1 ^= len;
  h1 = fmix32(h1);
  return h1;
}

static inline unsigned int encode_pos (
  size_t pos,
  unsigned int dim,
  unsigned int n_dims,
  unsigned int buckets,
  unsigned int wavelength
) {
  double angle = (double) pos / pow(wavelength * 1.0, (2.0 * ((double) (n_dims - dim) / 2)) / (double) n_dims);
  double val = (dim % 2 == 0) ? sin(angle) : cos(angle);
  return (unsigned int) round((val + 1.0) / 2.0 * (buckets - 1));
}

static inline void populate_set_of_clusters (
  lua_State *L,
  uint32_t *result,
  unsigned int result_len,
  unsigned int n,
  unsigned int n_clusters
) {
  // tbl, rlen
  for (unsigned int i = 0; i < result_len; i ++)
    result[i] = 0;
  for (unsigned int i = 0; i < n; i ++) {
    lua_pushinteger(L, i + 1); // tbl, rlen, i
    lua_gettable(L, 1); // tbl, rlen, token
    unsigned int token = tk_lua_checkunsigned(L, -1) - 1;
    lua_pop(L, 1); // tbl, rlen
    unsigned int chunk = token / BITS;
    unsigned int bit = token % BITS;
    result[chunk] |= (1 << bit);
  }
}

static inline void populate_simhash (
  lua_State *L,
  uint32_t *result,
  unsigned int n,
  unsigned int dimensions,
  unsigned int buckets,
  unsigned int wavelength
) {
  double counts[dimensions * BITS];
  for (unsigned int i = 0; i < dimensions * BITS; i ++)
    counts[i] = 0;

  unsigned int data[2];

  for (unsigned int i = 0; i < n; i ++) {

    lua_pushinteger(L, i + 1); // n
    lua_gettable(L, 1); // token

    lua_pushinteger(L, i + 1); // token n
    lua_gettable(L, 2); // token position

    lua_pushinteger(L, i + 1); // token position n
    lua_gettable(L, 3); // token position similarity

    lua_pushvalue(L, -3); // token position similarity token
    lua_gettable(L, 4); // token position similarity weight

    unsigned int token = tk_lua_checkunsigned(L, -4);
    unsigned int position = tk_lua_checkunsigned(L, -3);
    double similarity = tk_lua_checkposdouble(L, -2);
    double weight = tk_lua_optposdouble(L, -1, 0);

    lua_pop(L, 4);

    data[0] = token;
    for (unsigned int dimension = 0; dimension < dimensions; dimension ++) {
      data[1] = encode_pos(position, dimension, dimensions, buckets, wavelength);
      uint32_t hash = murmur32(data, sizeof(unsigned int) * 2, 0);
      for (unsigned int bit = 0; bit < BITS; bit ++) {
        if (hash & (1 << bit))
          counts[(dimension * BITS) + bit] += weight * similarity;
        else
          counts[(dimension * BITS) + bit] -= weight * similarity;
      }
    }

  }

  for (unsigned int i = 0; i < dimensions; i ++)
    result[i] = 0;

  for (unsigned int i = 0; i < dimensions * BITS; i ++) {
    unsigned int chunk = i / BITS;
    unsigned int bit = i % BITS;
    if (counts[i] > 0)
      result[chunk] |= (1 << bit);
  }

}

static inline int tb_set_of_clusters (lua_State *L)
{
  lua_settop(L, 2);
  luaL_checktype(L, 1, LUA_TTABLE);
  unsigned int n = tk_lua_len(L, 1);
  unsigned int n_clusters = tk_lua_checkunsigned(L, 2);
  unsigned int result_len = (n_clusters - 1) / BITS + 1;
  uint32_t result[result_len];
  populate_set_of_clusters(L, result, result_len, n, n_clusters);
  lua_pushlstring(L, (char *) result, result_len);
  lua_pushinteger(L, n_clusters);
  return 2;
}

static inline int tb_simhash (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checktype(L, 2, LUA_TTABLE);
  luaL_checktype(L, 3, LUA_TTABLE);
  luaL_checktype(L, 4, LUA_TTABLE);
  unsigned int n = tk_lua_len(L, 1);
  unsigned int dimensions = tk_lua_checkunsigned(L, 5);
  unsigned int buckets = tk_lua_checkunsigned(L, 6);
  unsigned int wavelength = tk_lua_checkunsigned(L, 7);
  if (!dimensions)
    luaL_argerror(L, 5, "dimensions must be greater than 0");
  if (!buckets)
    luaL_argerror(L, 6, "buckets must be greater than 0");
  if (!wavelength)
    luaL_argerror(L, 7, "wavelength must be greater than 0");
  uint32_t result[dimensions];
  populate_simhash(L, result, n, dimensions, buckets, wavelength);
  lua_pushlstring(L, (char *) result, dimensions * BYTES);
  lua_pushinteger(L, dimensions * BITS);
  return 2;
}

static inline int tb_position (lua_State *L)
{
  unsigned int position = tk_lua_checkunsigned(L, 1);
  unsigned int dimension = tk_lua_checkunsigned(L, 2);
  unsigned int dimensions = tk_lua_checkunsigned(L, 3);
  unsigned int buckets = tk_lua_checkunsigned(L, 4);
  unsigned int wavelength = tk_lua_checkunsigned(L, 5);
  lua_pushinteger(L, encode_pos(position, dimension, dimensions, buckets, wavelength));
  return 1;
}

static luaL_Reg tb_fns[] =
{
  { "simhash", tb_simhash },
  { "set_of_clusters", tb_set_of_clusters },
  { "position", tb_position },
  { NULL, NULL }
};

int luaopen_tbhss_hash (lua_State *L)
{
  lua_newtable(L); // t
  tk_lua_register(L, tb_fns, 0); // t

  lua_pushinteger(L, BITS); // t i
  lua_setfield(L, -2, "segment_bits"); // t

  return 1;
}
