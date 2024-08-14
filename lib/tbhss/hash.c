#include "lua.h"
#include "lauxlib.h"
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define BYTES (sizeof(uint32_t))
#define BITS (BYTES * CHAR_BIT)

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
  unsigned int buckets
) {
  double angle = (double) pos / pow(10000.0, (2.0 * ((double) dim / 2)) / (double) n_dims);
  double val = (dim % 2 == 0) ? sin(angle) : cos(angle);
  return (unsigned int) ((val + 1.0) / 2.0 * (buckets - 1));
}

static inline void populate_hash (
  lua_State *L,
  uint32_t *result,
  size_t n,
  unsigned int dimensions,
  unsigned int buckets
) {
  lua_Number counts[dimensions * BITS];
  for (size_t i = 0; i < dimensions * BITS; i ++)
    counts[i] = 0;

  lua_Integer data[2];

  for (size_t i = 0; i < n; i ++) {

    lua_pushinteger(L, i + 1); // n
    lua_gettable(L, 1); // token

    lua_pushinteger(L, i + 1); // token n
    lua_gettable(L, 2); // token position

    lua_pushinteger(L, i + 1); // token position n
    lua_gettable(L, 3); // token position similarity

    lua_pushvalue(L, -3); // token position similarity token
    lua_gettable(L, 4); // token position similarity weight

    lua_Integer token = luaL_checkinteger(L, -4);
    lua_Integer position = luaL_checkinteger(L, -3);
    lua_Number similarity = luaL_checknumber(L, -2);
    lua_Number weight = luaL_optnumber(L, -1, 0);

    lua_pop(L, 4);

    data[0] = token;
    for (unsigned int dimension = 0; dimension < dimensions; dimension ++) {
      data[1] = encode_pos(position, dimension, dimensions, buckets);
      uint32_t hash = murmur32(data, sizeof(lua_Integer) * 2, 0);
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

static inline int tb_simhash (lua_State *L)
{
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checktype(L, 2, LUA_TTABLE);
  luaL_checktype(L, 3, LUA_TTABLE);
  luaL_checktype(L, 4, LUA_TTABLE);
  size_t n = lua_objlen(L, 1);
  unsigned int dimensions = tk_lua_checkunsigned(L, 5);
  unsigned int buckets = tk_lua_checkunsigned(L, 6);
  if (!dimensions)
    luaL_argerror(L, 5, "dimensions must be greater than 0");
  if (!buckets)
    luaL_argerror(L, 6, "buckets must be greater than 0");
  uint32_t result[dimensions];
  populate_hash(L, result, n, dimensions, buckets);
  lua_pushlstring(L, (char *) result, dimensions * BYTES);
  lua_pushinteger(L, dimensions * BITS);
  return 2;
}

static luaL_Reg tb_fns[] =
{
  { "simhash", tb_simhash },
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
