#include "lua.h"
#include "lauxlib.h"
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <assert.h>
#include <ctype.h>

#include "roaring.h"
#include "roaring.c"
#include "khash.h"
#include "kbtree.h"
#include "kvec.h"

#define MT_BITMAP "santoku_bitmap"
#define MT_TOKENIZER "santoku_bpe_tokenizer"

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

static inline unsigned int tk_lua_checkunsigned (lua_State *L, int i)
{
  lua_Integer l = luaL_checkinteger(L, i);
  if (l < 0)
    luaL_error(L, "value can't be negative");
  if (l > UINT_MAX)
    luaL_error(L, "value is too large");
  return (unsigned int) l;
}

static inline const char *tk_lua_fchecklstring (lua_State *L, int i, char *field, size_t *len)
{
  lua_getfield(L, i, field);
  const char *s = luaL_checklstring(L, -1, len);
  lua_pop(L, 1);
  return s;
}

static inline lua_Integer tk_lua_fcheckunsigned (lua_State *L, int i, char *field)
{
  lua_getfield(L, i, field);
  lua_Integer n = tk_lua_checkunsigned(L, -1);
  lua_pop(L, 1);
  return n;
}

typedef struct { int a; int b; } tb_pair_t;
typedef struct { int t; size_t p; } tb_token_t;

static inline khint_t tb_freqs_hash (tb_pair_t p) {
  return (khint_t) (p.a * 31 + p.b);
}

static inline int tb_freqs_equals (tb_pair_t a, tb_pair_t b) {
  return a.a == b.a && a.b == b.b;
}

static inline int tb_tok_cmp (tb_token_t a, tb_token_t b) {
  if (a.p < b.p) return -1;
  if (a.p > b.p) return 1;
  return 0;
}

KHASH_MAP_INIT_STR(ids, int);
KHASH_MAP_INIT_INT(strs, const char *);
KBTREE_INIT(tokens, tb_token_t, tb_tok_cmp);
KHASH_INIT(freqs, tb_pair_t, int, 1, tb_freqs_hash, tb_freqs_equals);

typedef kbtree_t(tokens) tb_tokens_t;
typedef kvec_t(int) tb_deletes_t;
typedef khash_t(ids) tb_ids_t;
typedef khash_t(strs) tb_strs_t;
typedef khash_t(freqs) tb_freqs_t;

typedef struct {
  unsigned int vocab;
  unsigned int wavelength;
  unsigned int dimensions;
  unsigned int buckets;
  tb_deletes_t deletes;
  tb_tokens_t *tokens;
  tb_ids_t *ids;
  tb_strs_t *strs;
  tb_freqs_t *freqs;
  int next_id;
  bool collected;
} tb_bpe_t;

static tb_bpe_t *peek_bpe (lua_State *L, int i)
{
  return (tb_bpe_t *) luaL_checkudata(L, i, MT_TOKENIZER);
}

static inline int tb_bpe_gc (lua_State *L)
{
  tb_bpe_t *bpe = peek_bpe(L, 1);
  if (bpe->collected)
    return 0;
  bpe->collected = true;
  for (khint_t k = 0; k < kh_end(bpe->strs); k ++)
    if (kh_exist(bpe->strs, k))
       free((char *) kh_value(bpe->strs, k));
  kh_destroy(ids, bpe->ids);
  kh_destroy(strs, bpe->strs);
  kh_destroy(freqs, bpe->freqs);
  kb_destroy(tokens, bpe->tokens);
  kv_destroy(bpe->deletes);
  return 0;
}

static inline int tb_bpe_destroy (lua_State *L)
{
  lua_settop(L, 0);
  lua_pushvalue(L, lua_upvalueindex(1));
  return tb_bpe_gc(L);
}

static inline int tb_bpe_persist (lua_State *L)
{
  // Will do this later
  return 0;
}

static inline void tb_bpe_init_tokens (
  tb_bpe_t *bpe,
  const char *doc,
  size_t len
) {
  kb_destroy(tokens, bpe->tokens);
  bpe->tokens = kb_init(tokens, KB_DEFAULT_SIZE);
  int pos = 0;
  for (size_t i = 0; i < len; i++) {
    if (isspace(doc[i]) && i < len - 1 && isspace(doc[i + 1]))
      continue;
    char tmp[2] = {0};
    tmp[0] = isspace(doc[i]) ? ' ' : doc[i];
    int absent;
    khint_t k = kh_put(ids, bpe->ids, tmp, &absent);
    int id;
    if (absent) {
      // TODO: how to best handle unknown tokens?
      continue;
    } else {
      id = kh_value(bpe->ids, k);
    }
    tb_token_t t = { .t = id, .p = pos ++ };
    kb_put(tokens, bpe->tokens, t);
  }
}

static inline const char *tb_bpe_id_str (
  tb_bpe_t *bpe,
  int id
) {
  khint_t k = kh_get(strs, bpe->strs, id);
  assert(k != kh_end(bpe->strs));
  return kh_value(bpe->strs, k);
}

static inline int tb_bpe_tokenize (lua_State *L)
{
  tb_bpe_t *bpe = peek_bpe(L, lua_upvalueindex(1));
  size_t len;
  const char *doc = luaL_checklstring(L, 1, &len);
  tb_bpe_init_tokens(bpe, doc, len);
  bool changed = true;
  while (changed) {
    changed = false;
    kbitr_t itr;
    kb_itr_first(tokens, bpe->tokens, &itr);
    if (!kb_itr_valid(&itr))
      break;
    tb_token_t left = kb_itr_key(tb_token_t, &itr);
    kb_itr_next(tokens, bpe->tokens, &itr);
    while (kb_itr_valid(&itr)) {
      tb_token_t right = kb_itr_key(tb_token_t, &itr);
      const char *left_str  = tb_bpe_id_str(bpe, left.t);
      const char *right_str = tb_bpe_id_str(bpe, right.t);
      char *cat = malloc(strlen(left_str) + strlen(right_str) + 1);
      strcpy(cat, left_str);
      strcat(cat, right_str);
      khint_t k = kh_get(ids, bpe->ids, cat);
      if (k != kh_end(bpe->ids)) {
        int merged_id = kh_value(bpe->ids, k);
        kv_push(int, bpe->deletes, left.p);
        right.t = merged_id;
        kb_itr_key(tb_token_t, &itr) = right;
        changed = true;
        left = right;
      } else {
        left = right;
      }
      free(cat);
      kb_itr_next(tokens, bpe->tokens, &itr);
    }
    for (size_t i = 0; i < kv_size(bpe->deletes); i ++) {
      tb_token_t tmp = { .t = 0, .p = kv_A(bpe->deletes, i) };
      kb_del(tokens, bpe->tokens, tmp);
    }
    kv_size(bpe->deletes) = 0;
  }
  roaring64_bitmap_t *bm = roaring64_bitmap_create();
  if (bm == NULL)
    luaL_error(L, "memory error creating bitmap");
  roaring64_bitmap_t **bmp = (roaring64_bitmap_t **)
    lua_newuserdata(L, sizeof(roaring64_bitmap_t *)); // t, n, b
  *bmp = bm;
  luaL_getmetatable(L, MT_BITMAP); // t, n, b, mt
  lua_setmetatable(L, -2); // t, n, b
  kbitr_t itr;
  kb_itr_first(tokens, bpe->tokens, &itr);
  for (; kb_itr_valid(&itr); kb_itr_next(tokens, bpe->tokens, &itr))
    roaring64_bitmap_add(bm, kb_itr_key(tb_token_t, &itr).t);
  return 1;
}

static inline tb_pair_t tb_bpe_top_pair (
  tb_bpe_t *bpe,
  int *count
) {
  tb_pair_t topp;
  int topv = 0;
  for (khint_t k = 0; k < kh_end(bpe->freqs); k ++)
    if (kh_exist(bpe->freqs, k) && kh_value(bpe->freqs, k) > topv) {
      topp = kh_key(bpe->freqs, k);
      topv = kh_value(bpe->freqs, k);
    }
  *count = topv;
  return topp;
}

static inline void tb_bpe_count_frequencies (
  tb_bpe_t *bpe
) {
  khint_t k;
  kh_destroy(freqs, bpe->freqs);
  bpe->freqs = kh_init(freqs);
  for (k = 0; k < kh_end(bpe->freqs); ++k)
    if (kh_exist(bpe->freqs, k))
      kh_del(freqs, bpe->freqs, k);
  int absent;
  tb_pair_t pair;
  kbitr_t itr;
  kb_itr_first(tokens, bpe->tokens, &itr);
  assert(kb_itr_valid(&itr));
  pair.a = kb_itr_key(tb_token_t, &itr).t;
  kb_itr_next(tokens, bpe->tokens, &itr);
  for (; kb_itr_valid(&itr); kb_itr_next(tokens, bpe->tokens, &itr)) {
    pair.b = kb_itr_key(tb_token_t, &itr).t;
    k = kh_put(freqs, bpe->freqs, pair, &absent);
    if (absent) {
      kh_key(bpe->freqs, k) = pair;
      kh_value(bpe->freqs, k) = 1;
    } else {
      kh_value(bpe->freqs, k) ++;
    }
    pair.a = pair.b;
  }
}

static inline int tb_bpe_new_token (
  tb_bpe_t *bpe,
  tb_pair_t pair
) {
  const char *a = tb_bpe_id_str(bpe, pair.a);
  const char *b = tb_bpe_id_str(bpe, pair.b);
  char *c = malloc(strlen(a) + strlen(b) + 1);
  strcpy(c, a);
  strcat(c, b);
  int absent;
  khint_t k;
  k = kh_put(ids, bpe->ids, c, &absent);
  assert(absent == 1);
  int id = bpe->next_id ++;
  kh_value(bpe->ids, k) = id;
  k = kh_put(strs, bpe->strs, id, &absent);
  assert(absent == 1);
  kh_value(bpe->strs, k) = c;
  return id;
}

static inline void tb_bpe_first_pass (
  tb_bpe_t *bpe,
  const char *corpus,
  size_t len
) {
  khint_t k;
  int absent;
  char tmp[2] = {0};
  int pos = 0;
  int id;
  for (size_t i = 0; i < len; i ++) {
    if (isspace(corpus[i]) && i < len - 1 && isspace(corpus[i + 1]))
      continue;
    tmp[0] = isspace(corpus[i]) ? ' ' : corpus[i];
    k = kh_put(ids, bpe->ids, tmp, &absent);
    if (absent) {
      id = bpe->next_id ++;
      char *tok = strdup(tmp);
      kh_key(bpe->ids, k) = tok;
      kh_value(bpe->ids, k) = id;
      k = kh_put(strs, bpe->strs, id, &absent);
      assert(absent == 1);
      kh_value(bpe->strs, k) = tok;
    } else  {
      id = kh_value(bpe->ids, k);
    }
    tb_token_t t = { .t = id, .p = pos ++ };
    kb_put(tokens, bpe->tokens, t);
  }
}

static inline void tb_bpe_update_corpus (
  tb_bpe_t *bpe,
  tb_pair_t find,
  int id
) {
  tb_token_t a;
  tb_token_t *b;
  kbitr_t itr;
  kb_itr_first(tokens, bpe->tokens, &itr);
  assert(kb_itr_valid(&itr));
  a = kb_itr_key(tb_token_t, &itr);
  kb_itr_next(tokens, bpe->tokens, &itr);
  while (kb_itr_valid(&itr)) {
    b = &kb_itr_key(tb_token_t, &itr);
    if (find.a == a.t && find.b == b->t) {
      kv_push(int, bpe->deletes, a.p);
      b->t = id;
    }
    a = *b;
    kb_itr_next(tokens, bpe->tokens, &itr);
  }
  for (size_t i = 0; i < kv_size(bpe->deletes); i ++) {
    a.p = kv_A(bpe->deletes, i);
    kb_del(tokens, bpe->tokens, a);
  }
  kv_size(bpe->deletes) = 0;
}

static inline int tb_bpe_train (lua_State *L)
{
  tb_bpe_t *bpe = peek_bpe(L, lua_upvalueindex(1));
  size_t len;
  const char *corpus = tk_lua_fchecklstring(L, 1, "corpus", &len);
  tb_bpe_first_pass(bpe, corpus, len);
  if (bpe->next_id >= bpe->vocab)
    return 0;
  for (unsigned int i = 0; i < bpe->vocab - (bpe->next_id - 1); i ++) {
    tb_bpe_count_frequencies(bpe);
    int count;
    tb_pair_t top = tb_bpe_top_pair(bpe, &count);
    int new = tb_bpe_new_token(bpe, top);
    tb_bpe_update_corpus(bpe, top, new);
  }
  lua_pushinteger(L, bpe->next_id);
  return 1;
}

static luaL_Reg tb_mt_fns[] =
{
  { "train", tb_bpe_train },
  { "tokenize", tb_bpe_tokenize },
  { "persist", tb_bpe_persist },
  { "destroy", tb_bpe_destroy },
  { NULL, NULL }
};

static inline int tb_bpe_create (lua_State *L)
{
  lua_settop(L, 1);
  unsigned int vocab = tk_lua_fcheckunsigned(L, 1, "vocab");
  unsigned int wavelength = tk_lua_fcheckunsigned(L, 1, "wavelength");
  unsigned int dimensions = tk_lua_fcheckunsigned(L, 1, "dimensions");
  unsigned int buckets = tk_lua_fcheckunsigned(L, 1, "buckets");
  tb_bpe_t *bpe = lua_newuserdata(L, sizeof(tb_bpe_t));
  memset(bpe, 0, sizeof(tb_bpe_t)); // b
  luaL_getmetatable(L, MT_TOKENIZER); // b mt
  lua_setmetatable(L, -2); // b
  kv_init(bpe->deletes);
  bpe->ids = kh_init(ids);
  bpe->strs = kh_init(strs);
  bpe->tokens = kb_init(tokens, KB_DEFAULT_SIZE);
  bpe->freqs = kh_init(freqs);
  bpe->next_id = 1;
  bpe->vocab = vocab;
  bpe->wavelength = wavelength;
  bpe->dimensions = dimensions;
  bpe->buckets = buckets;
  lua_newtable(L); // b t
  lua_pushvalue(L, -2); // b t b
  tk_lua_register(L, tb_mt_fns, 1); // b t
  return 1;
}

static inline int tb_bpe_load (lua_State *L)
{
  // Will do this later
  return 0;
}

static luaL_Reg tb_fns[] =
{
  { "create", tb_bpe_create },
  { "load", tb_bpe_load },
  { NULL, NULL }
};

int luaopen_tbhss_bpe (lua_State *L)
{
  lua_newtable(L); // t
  tk_lua_register(L, tb_fns, 0); // t
  luaL_newmetatable(L, MT_TOKENIZER); // t mt
  lua_pushcfunction(L, tb_bpe_gc); // t mt fn
  lua_setfield(L, -2, "__gc"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
