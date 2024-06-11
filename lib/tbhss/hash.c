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

static inline void aggregate (uint32_t *hashes, size_t n, uint32_t *out, unsigned int segments)
{
  uint32_t counts[segments * 32];
  memset(counts, 0, sizeof(uint32_t) * segments * 32);
  for (size_t i = 0; i < n; i ++) {
    uint32_t *hash = hashes + i * segments * 2;
    for (unsigned int j = 0; j < segments * 32; j ++) {
      unsigned int chunk = j / (sizeof(uint32_t) * CHAR_BIT);
      unsigned int pos = j % (sizeof(uint32_t) * CHAR_BIT);
      if (hash[chunk] & (1 << pos))
        counts[j] ++;
    }
  }
  for (unsigned int j = 0; j < segments * 32; j ++) {
    unsigned int chunk = j / (sizeof(uint32_t) * CHAR_BIT);
    unsigned int pos = j % (sizeof(uint32_t) * CHAR_BIT);
    if (counts[j] >= n / 2)
      out[chunk] |= (1 << pos);
  }
}

static inline void populate_token_hashes (
  lua_State *L,
  uint32_t *token_hashes,
  size_t n,
  unsigned int segments,
  unsigned int hash_chunks
) {
  memset(token_hashes, 0, sizeof(uint32_t) * hash_chunks * n);
  for (size_t i = 0; i < n; i ++) {
    uint32_t *token_hash = token_hashes + i * hash_chunks;
    lua_pushinteger(L, i + 1); // t i
    lua_gettable(L, 1); // t v
    lua_Integer x = luaL_checkinteger(L, -1);
    lua_pop(L, 1); // t
    murmur(&x, sizeof(x), 0, token_hash, segments);
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
  size_t n_tokens,
  unsigned int segments,
  unsigned int dimensions,
  unsigned int hash_chunks,
  unsigned int pos_buckets
) {
  memset(pos_hashes, 0, sizeof(uint32_t) * hash_chunks * dimensions * n_tokens);
  for (size_t i = 0; i < n_tokens; i ++) {
    for (unsigned int j = 0; j < dimensions; j ++) {
      uint32_t *pos_hash = pos_hashes + (i * dimensions * hash_chunks) + (j * hash_chunks);
      lua_pushinteger(L, i + 1); // t i
      lua_gettable(L, 1); // t v
      unsigned int input[2] = {
        tk_lua_checkunsigned(L, -1),
        encode_pos(i, j, dimensions, pos_buckets)
      };
      lua_pop(L, 1); // t
      murmur(input, sizeof(unsigned int) * 2, 0, pos_hash, segments);
    }
  }
}

static inline void aggregate_results (
  uint32_t *token_hashes,
  uint32_t *pos_hashes,
  uint32_t *result,
  size_t n,
  unsigned int segments,
  unsigned int pos_dimensions,
  unsigned int hash_chunks
) {
  memset(result, 0, sizeof(uint32_t) * hash_chunks);
  aggregate(token_hashes, n, result, segments);
  aggregate(pos_hashes, n * pos_dimensions, &result[segments], segments);
}

// Given a table of integers (tokens), return a fingerprint. The first half of
// the bits are a traditional simhash, the second half are a simhash with
// sinusoidal positional encodings XOR'd to token hashes.
// TODO: bm25 weighting
static inline int tb_fingerprint (lua_State *L)
{
  lua_settop(L, 4);
  luaL_checktype(L, 1, LUA_TTABLE);
  size_t n = lua_objlen(L, 1);
  unsigned int segments = tk_lua_checkunsigned(L, 2);
  unsigned int pos_dimensions = tk_lua_checkunsigned(L, 3);
  unsigned int pos_buckets = tk_lua_checkunsigned(L, 4);
  size_t hash_chunks = segments * 2;
  // TODO: Can we avoid malloc each time?
  uint32_t *token_hashes = malloc(sizeof(uint32_t) * hash_chunks * n);
  uint32_t *pos_hashes = malloc(sizeof(uint32_t) * hash_chunks * pos_dimensions * n);
  uint32_t result[hash_chunks];
  populate_token_hashes(L, token_hashes, n, segments, hash_chunks);
  populate_pos_hashes(L, pos_hashes, n, segments, pos_dimensions, hash_chunks, pos_buckets);
  aggregate_results(token_hashes, pos_hashes, result, n, segments, pos_dimensions, hash_chunks);
  lua_pushlstring(L, (char *) result, sizeof(uint32_t) * hash_chunks);
  lua_pushinteger(L, hash_chunks * 32);
  free(token_hashes);
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
