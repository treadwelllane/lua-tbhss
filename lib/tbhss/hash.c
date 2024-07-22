#include "lua.h"
#include "lauxlib.h"
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

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

static inline void murmur (const void *key, const int len, uint32_t seed, uint32_t *out, unsigned int segments)
{
  for (unsigned int i = 0; i < segments; i ++)
    out[i] = murmur32(key, len, i == 0 ? 0 : out[i - 1]);
}

static inline void aggregate (
  lua_State *L,
  uint32_t *hashes,
  size_t n,
  uint32_t *out,
  unsigned int segments,
  unsigned int dimensions
) {
  unsigned int positive[segments * dimensions * 32];
  unsigned int negative[segments * dimensions * 32];
  memset(positive, 0, sizeof(unsigned int) * segments * dimensions * 32);
  memset(negative, 0, sizeof(unsigned int) * segments * dimensions * 32);
  for (size_t i = 0; i < n; i ++) {
    lua_pushinteger(L, i + 1); // n
    lua_gettable(L, 1); // tok
    lua_gettable(L, 2); // weight
    // TODO: This currently causes all terms without weights to be ignored from
    // the model
    unsigned int weight  = tk_lua_optunsigned(L, -1, 0);
    lua_pop(L, 1); //
    uint32_t *hash = hashes + i * segments * dimensions;
    for (unsigned int j = 0; j < segments * dimensions * 32; j ++) {
      unsigned int chunk = j / (sizeof(uint32_t) * CHAR_BIT);
      unsigned int pos = j % (sizeof(uint32_t) * CHAR_BIT);
      if (hash[chunk] & (1 << pos))
        positive[j] += weight;
      else
        negative[j] += weight;
    }
  }
  for (unsigned int j = 0; j < segments * dimensions * 32; j ++) {
    unsigned int chunk = j / (sizeof(uint32_t) * CHAR_BIT);
    unsigned int pos = j % (sizeof(uint32_t) * CHAR_BIT);
    if (positive[j] > negative[j])
      out[chunk] |= (1 << pos);
  }
}

static inline void populate_topic_hashes (
  lua_State *L,
  uint32_t *topic_hashes,
  size_t n,
  unsigned int topic_segments
) {
  memset(topic_hashes, 0, sizeof(uint32_t) * n * topic_segments);
  for (size_t i = 0; i < n; i ++) {
    uint32_t *topic_hash = topic_hashes + i * topic_segments;
    lua_pushinteger(L, i + 1); // t i
    lua_gettable(L, 1); // t v
    lua_Integer x = luaL_checkinteger(L, -1);
    lua_pop(L, 1); // t
    murmur(&x, sizeof(x), 0, topic_hash, topic_segments);
  }
}

static inline unsigned int encode_pos (
  size_t pos,
  unsigned int dim,
  unsigned int n_dims,
  unsigned int pos_buckets
) {
  double angle = (double) pos / pow(10000.0, (2.0 * ((double) dim / 2)) / (double) n_dims);
  double val = (dim % 2 == 0) ? sin(angle) : cos(angle);
  return (unsigned int) ((val + 1.0) / 2.0 * (pos_buckets - 1));
}

static inline void populate_pos_hashes (
  lua_State *L,
  uint32_t *pos_hashes,
  size_t n,
  unsigned int pos_segments,
  unsigned int pos_dimensions,
  unsigned int pos_buckets
) {
  memset(pos_hashes, 0, sizeof(uint32_t) * n * pos_segments * pos_dimensions);
  unsigned int pos = 0;
  for (size_t i = 0; i < n; i ++) {
    for (unsigned int j = 0; j < pos_dimensions; j ++) {
      uint32_t *pos_hash = pos_hashes + (i * pos_segments * pos_dimensions) + (j * pos_segments);
      lua_pushinteger(L, i + 1); // t i
      lua_gettable(L, 1); // t v
      lua_Integer t = luaL_checkinteger(L, -1);
      if (t > 0)
        pos ++;
      unsigned int input[2] = { t, encode_pos(pos, j, pos_dimensions, pos_buckets) };
      lua_pop(L, 1); // t
      murmur(input, sizeof(unsigned int) * 2, 0, pos_hash, pos_segments);
    }
  }
}

static inline void aggregate_results (
  lua_State *L,
  uint32_t *topic_hashes,
  uint32_t *pos_hashes,
  uint32_t *result,
  size_t n,
  unsigned int topic_segments,
  unsigned int pos_segments,
  unsigned int pos_dimensions
) {
  memset(result, 0, sizeof(uint32_t) * (topic_segments + pos_segments * pos_dimensions));
  aggregate(L, topic_hashes, n, result, topic_segments, 1);
  aggregate(L, pos_hashes, n, &result[topic_segments], pos_segments, pos_dimensions);
}

// Given a table of integers (tokens), return a fingerprint. The first half of
// the bits are a traditional simhash, the second half are a simhash with
// sinusoidal positional encodings XOR'd to token hashes.
// TODO: bm25 weighting
static inline int tb_fingerprint (lua_State *L)
{
  lua_settop(L, 6);
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checktype(L, 2, LUA_TTABLE);
  size_t n = lua_objlen(L, 1);
  unsigned int topic_segments = tk_lua_checkunsigned(L, 3);
  unsigned int pos_segments = tk_lua_checkunsigned(L, 4);
  unsigned int pos_dimensions = tk_lua_checkunsigned(L, 5);
  unsigned int pos_buckets = tk_lua_checkunsigned(L, 6);
  uint32_t *topic_hashes = malloc(sizeof(uint32_t) * n * topic_segments);
  uint32_t *pos_hashes = malloc(sizeof(uint32_t) * n * pos_segments * pos_dimensions);
  uint32_t result[topic_segments + pos_segments * pos_dimensions];
  populate_topic_hashes(L, topic_hashes, n, topic_segments);
  populate_pos_hashes(L, pos_hashes, n, pos_segments, pos_dimensions, pos_buckets);
  aggregate_results(L, topic_hashes, pos_hashes, result, n, topic_segments, pos_segments, pos_dimensions);
  lua_pushlstring(L, (char *) result, sizeof(uint32_t) * (topic_segments + pos_segments * pos_dimensions));
  lua_pushinteger(L, (topic_segments + pos_segments * pos_dimensions) * 32);
  free(topic_hashes);
  free(pos_hashes);
  return 2;
}

static luaL_Reg tb_fns[] =
  {
    { "fingerprint", tb_fingerprint },
    { NULL, NULL }
  };

int luaopen_tbhss_hash (lua_State *L)
{
  lua_newtable(L); // t
  tk_lua_register(L, tb_fns, 0); // t

  lua_pushinteger(L, sizeof(uint32_t) * CHAR_BIT); // t i
  lua_setfield(L, -2, "segment_bits"); // t

  return 1;
}
