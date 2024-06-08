#include "lua.h"
#include "lauxlib.h"
#include <stdint.h>
#include <string.h>

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

static inline uint64_t murmur (
  const char *key,
  uint32_t len,
  uint32_t seed
) {
  const uint64_t c1 = 0x87c37b91114253d5;
  const uint64_t c2 = 0x4cf5ad432745937f;
  uint64_t h1 = seed;
  uint64_t h2 = seed;
  const uint64_t *blocks = (const uint64_t *)(key);
  int nblocks = len / 8;
  for (int i = 0; i < nblocks; i ++) {
    uint64_t k1 = blocks[i * 2 + 0];
    uint64_t k2 = blocks[i * 2 + 1];
    k1 *= c1;
    k1 = (k1 << 31) | (k1 >> 33);
    k1 *= c2;
    h1 ^= k1;
    h1 = (h1 << 27) | (h1 >> 37);
    h1 += h2;
    h1 = h1 * 5 + 0x52dce729;
    k2 *= c2;
    k2 = (k2 << 33) | (k2 >> 31);
    k2 *= c1;
    h2 ^= k2;
    h2 = (h2 << 31) | (h2 >> 33);
    h2 += h1;
    h2 = h2 * 5 + 0x38495ab5;
  }
  const uint8_t *tail = (const uint8_t *)(key + nblocks * 8);
  uint64_t k1 = 0;
  uint64_t k2 = 0;
  switch (len & 15) {
    case 15: k2 ^= ((uint64_t)tail[14]) << 48;
    case 14: k2 ^= ((uint64_t)tail[13]) << 40;
    case 13: k2 ^= ((uint64_t)tail[12]) << 32;
    case 12: k2 ^= ((uint64_t)tail[11]) << 24;
    case 11: k2 ^= ((uint64_t)tail[10]) << 16;
    case 10: k2 ^= ((uint64_t)tail[9]) << 8;
    case 9: k2 ^= ((uint64_t)tail[8]) << 0;
      k2 *= c2;
      k2 = (k2 << 33) | (k2 >> 31);
      k2 *= c1;
      h2 ^= k2;
    case 8: k1 ^= ((uint64_t)tail[7]) << 56;
    case 7: k1 ^= ((uint64_t)tail[6]) << 48;
    case 6: k1 ^= ((uint64_t)tail[5]) << 40;
    case 5: k1 ^= ((uint64_t)tail[4]) << 32;
    case 4: k1 ^= ((uint64_t)tail[3]) << 24;
    case 3: k1 ^= ((uint64_t)tail[2]) << 16;
    case 2: k1 ^= ((uint64_t)tail[1]) << 8;
    case 1: k1 ^= ((uint64_t)tail[0]) << 0;
      k1 *= c1;
      k1 = (k1 << 31) | (k1 >> 33);
      k1 *= c2;
      h1 ^= k1;
  }
  h1 ^= len;
  h2 ^= len;
  h1 += h2;
  h2 += h1;
  h1 ^= h1 >> 33;
  h1 *= 0xff51afd7ed558ccd;
  h1 ^= h1 >> 33;
  h1 *= 0xc4ceb9fe1a85ec53;
  h1 ^= h1 >> 33;
  h2 ^= h2 >> 33;
  h2 *= 0xff51afd7ed558ccd;
  h2 ^= h2 >> 33;
  h2 *= 0xc4ceb9fe1a85ec53;
  h2 ^= h2 >> 33;
  h1 += h2;
  h2 += h1;
  return h1;
}

static inline void fingerprint (
  const char *data,
  size_t len,
  uint64_t *out,
  unsigned int segments
) {
  size_t segment_len = (len - 2) / segments;
  for (unsigned int s = 0; s < segments; s ++) {
    int bits[64] = {0};
    size_t start = s * segment_len;
    size_t end = (s == segments - 1) ? len - 2 : (s + 1) * segment_len;
    for (size_t i = start; i < end; i ++) {
      char trigram[4];
      memcpy(trigram, &data[i], 3);
      trigram[3] = '\0';
      uint64_t hash = murmur(trigram, 3, 0);
      for (int j = 0; j < 64; j ++) {
        bits[j] += (hash & 1) ? 1 : -1;
        hash >>= 1;
      }
    }
    uint64_t fingerprint = 0;
    for (int i = 0; i < 64; i ++) {
      if (bits[i] > 0) fingerprint |= (1ULL << i);
    }
    out[s] = fingerprint;
  }
}

static inline int tb_hash (lua_State *L)
{
  size_t len;
  const char *str = luaL_checklstring(L, 1, &len);
  unsigned int segments = tk_lua_optunsigned(L, 2, 1);
  uint64_t h[segments];
  memset(h, 0, sizeof(uint64_t) * segments);
  fingerprint(str, len, h, segments);
  lua_pushlstring(L, (char *) h, sizeof(uint64_t) * segments);
  return 1;
}

int luaopen_tbhss_hash (lua_State *L)
{
  lua_pushcfunction(L, tb_hash);
  return 1;
}
