#include "lua.h"
#include "lauxlib.h"
#include <stdint.h>
#include <assert.h>
#include <errno.h>
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

static inline void tk_lua_callmod (lua_State *L, int nargs, int nret, const char *smod, const char *sfn)
{
  lua_getglobal(L, "require");
  lua_pushstring(L, smod);
  lua_call(L, 1, 1);
  lua_pushstring(L, sfn);
  lua_gettable(L, -2);
  lua_remove(L, -2);
  lua_insert(L, - nargs - 1);
  lua_call(L, nargs, nret);
}

static inline int tk_lua_errno (lua_State *L, int err)
{
  lua_pushstring(L, strerror(errno));
  lua_pushinteger(L, err);
  tk_lua_callmod(L, 2, 0, "santoku.error", "error");
  return 0;
}

static inline int tk_lua_errmalloc (lua_State *L)
{
  lua_pushstring(L, "Error in malloc");
  tk_lua_callmod(L, 1, 0, "santoku.error", "error");
  return 0;
}

static inline FILE *tk_lua_tmpfile (lua_State *L)
{
  FILE *fh = tmpfile();
  if (fh) return fh;
  int e = errno;
  lua_settop(L, 0);
  lua_pushstring(L, "Error opening tmpfile");
  lua_pushstring(L, strerror(e));
  lua_pushinteger(L, e);
  tk_lua_callmod(L, 3, 0, "santoku.error", "error");
  return NULL;
}

static inline FILE *tk_lua_fmemopen (lua_State *L, char *data, size_t size, const char *flag)
{
  FILE *fh = fmemopen(data, size, flag);
  if (fh) return fh;
  int e = errno;
  lua_settop(L, 0);
  lua_pushstring(L, "Error opening string as file");
  lua_pushstring(L, strerror(e));
  lua_pushinteger(L, e);
  tk_lua_callmod(L, 3, 0, "santoku.error", "error");
  return NULL;
}

static inline FILE *tk_lua_fopen (lua_State *L, const char *fp, const char *flag)
{
  FILE *fh = fopen(fp, flag);
  if (fh) return fh;
  int e = errno;
  lua_settop(L, 0);
  lua_pushstring(L, "Error opening file");
  lua_pushstring(L, fp);
  lua_pushstring(L, strerror(e));
  lua_pushinteger(L, e);
  tk_lua_callmod(L, 4, 0, "santoku.error", "error");
  return NULL;
}

static inline void tk_lua_fclose (lua_State *L, FILE *fh)
{
  if (!fclose(fh)) return;
  int e = errno;
  lua_settop(L, 0);
  lua_pushstring(L, "Error closing file");
  lua_pushstring(L, strerror(e));
  lua_pushinteger(L, e);
  tk_lua_callmod(L, 3, 0, "santoku.error", "error");
}

static inline void tk_lua_fwrite (lua_State *L, char *data, size_t size, size_t memb, FILE *fh)
{
  size_t bytes = fwrite(data, size, memb, fh);
  if (!ferror(fh) && bytes) return;
  int e = errno;
  lua_settop(L, 0);
  lua_pushstring(L, "Error writing to file");
  lua_pushstring(L, strerror(e));
  lua_pushinteger(L, e);
  tk_lua_callmod(L, 3, 0, "santoku.error", "error");
}

static inline void tk_lua_fread (lua_State *L, void *data, size_t size, size_t memb, FILE *fh)
{
  fread(data, size, memb, fh);
  if (!ferror(fh)) return;
  int e = errno;
  lua_settop(L, 0);
  lua_pushstring(L, "Error reading from file");
  lua_pushstring(L, strerror(e));
  lua_pushinteger(L, e);
  tk_lua_callmod(L, 3, 0, "santoku.error", "error");
}

static inline void tk_lua_fseek (lua_State *L, size_t size, size_t memb, FILE *fh)
{
  int r = fseek(fh, (long) (size * memb), SEEK_CUR);
  if (!ferror(fh) || !r) return;
  int e = errno;
  lua_settop(L, 0);
  lua_pushstring(L, "Error reading from file");
  lua_pushstring(L, strerror(e));
  lua_pushinteger(L, e);
  tk_lua_callmod(L, 3, 0, "santoku.error", "error");
}

static inline char *tk_lua_fslurp (lua_State *L, FILE *fh, size_t *len)
{
  if (fseek(fh, 0, SEEK_END) != 0) {
    tk_lua_errno(L, errno);
    return NULL;
  }
  long size = ftell(fh);
  if (size < 0) {
    tk_lua_errno(L, errno);
    return NULL;
  }
  if (fseek(fh, 0, SEEK_SET) != 0) {
    tk_lua_errno(L, errno);
    return NULL;
  }
  char *buffer = malloc((size_t) size);
  if (!buffer) {
    tk_lua_errmalloc(L);
    return NULL;
  }
  if (fread(buffer, 1, (size_t) size, fh) != (size_t) size) {
    free(buffer);
    tk_lua_errno(L, errno);
    return NULL;
  }
  *len = (size_t) size;
  return buffer;
}

static inline void tk_lua_register (lua_State *L, luaL_Reg *regs, int nup)
{
  while (true) {
    if ((*regs).name == NULL)
      break;
    for (int i = 0; i < nup; i ++)
      lua_pushvalue(L, -nup);
    lua_pushcclosure(L, (*regs).func, nup);
    lua_setfield(L, -nup - 2, (*regs).name);
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
  int next_id;
  size_t maxlen;
  tb_deletes_t deletes;
  tb_tokens_t *tokens;
  tb_ids_t *ids;
  tb_strs_t *strs;
  tb_freqs_t *freqs;
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
  for (khint_t k = kh_begin(bpe->strs); k < kh_end(bpe->strs); k ++)
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
  tb_bpe_t *bpe = peek_bpe(L, lua_upvalueindex(1));
  lua_settop(L, 1);
  bool tostr = lua_type(L, 1) == LUA_TNIL;
  FILE *fh;
  if (tostr)
    fh = tk_lua_tmpfile(L);
  else
    fh = tk_lua_fopen(L, luaL_checkstring(L, 1), "w");
  tk_lua_fwrite(L, (char *) &bpe->vocab, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &bpe->wavelength, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &bpe->dimensions, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &bpe->buckets, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &bpe->next_id, sizeof(int), 1, fh);
  tk_lua_fwrite(L, (char *) &bpe->maxlen, sizeof(size_t), 1, fh);
  tk_lua_fwrite(L, (char *) &kh_size(bpe->ids), sizeof(khint_t), 1, fh);
  for (khint_t i = kh_begin(bpe->ids); i < kh_end(bpe->ids); i ++)
    if (kh_exist(bpe->ids, i)) {
      char *tok = (char *) kh_key(bpe->ids, i);
      size_t len = strlen(tok);
      int id = kh_value(bpe->ids, i) ;
      tk_lua_fwrite(L, (char *) &len, sizeof(size_t), 1, fh);
      tk_lua_fwrite(L, tok, len, 1, fh);
      tk_lua_fwrite(L, (char *) &id, sizeof(int), 1, fh);
    }
  if (!tostr) {
    tk_lua_fclose(L, fh);
    return 0;
  } else {
    size_t len;
    char *data = tk_lua_fslurp(L, fh, &len);
    if (data) {
      lua_pushlstring(L, data, len);
      free(data);
      tk_lua_fclose(L, fh);
      return 1;
    } else {
      tk_lua_fclose(L, fh);
      return 0;
    }
  }
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

static inline bool tb_bpe_skipchar (char c) {
  return isspace(c) || ispunct(c);
}

static inline void tb_bpe_init_tokens (
  tb_bpe_t *bpe,
  const char *doc,
  size_t len
) {
  kb_destroy(tokens, bpe->tokens);
  bpe->tokens = kb_init(tokens, KB_DEFAULT_SIZE);
  int pos = 0;
  for (size_t i = 0; i < len; i ++) {
    if (tb_bpe_skipchar(doc[i]) && i < len - 1 && tb_bpe_skipchar(doc[i + 1]))
      continue;
    char tmp[2] = {0};
    tmp[0] = tb_bpe_skipchar(doc[i]) ? ' ' : tolower(doc[i]);
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

static inline void tb_bpe_populate_tokens (
  tb_bpe_t *bpe,
  const char *doc,
  size_t len
) {
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
    char cat[bpe->maxlen * 2 + 1];
    while (kb_itr_valid(&itr)) {
      tb_token_t right = kb_itr_key(tb_token_t, &itr);
      const char *left_str  = tb_bpe_id_str(bpe, left.t);
      const char *right_str = tb_bpe_id_str(bpe, right.t);
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
      kb_itr_next(tokens, bpe->tokens, &itr);
    }
    for (size_t i = 0; i < kv_size(bpe->deletes); i ++) {
      tb_token_t tmp = { .t = 0, .p = kv_A(bpe->deletes, i) };
      kb_del(tokens, bpe->tokens, tmp);
    }
    kv_size(bpe->deletes) = 0;
  }
}

static inline int tb_bpe_parse (lua_State *L)
{
  tb_bpe_t *bpe = peek_bpe(L, lua_upvalueindex(1));
  size_t len;
  const char *doc = luaL_checklstring(L, 1, &len);
  tb_bpe_populate_tokens(bpe, doc, len);
  lua_newtable(L);
  lua_Integer n = 1;
  kbitr_t itr;
  khint_t k;
  int absent;
  kb_itr_first(tokens, bpe->tokens, &itr);
  while (kb_itr_valid(&itr)) {
    int t = kb_itr_key(tb_token_t, &itr).t;
    k = kh_put(strs, bpe->strs, t, &absent);
    if (!absent) {
      lua_pushinteger(L, n);
      lua_pushstring(L, kh_value(bpe->strs, k));
      lua_settable(L, -3);
      n = n + 1;
    }
    kb_itr_next(tokens, bpe->tokens, &itr);
  }
  return 1;
}

static inline int tb_bpe_tokenize (lua_State *L)
{
  tb_bpe_t *bpe = peek_bpe(L, lua_upvalueindex(1));
  size_t len;
  const char *doc = luaL_checklstring(L, 1, &len);
  tb_bpe_populate_tokens(bpe, doc, len);
  roaring64_bitmap_t *bm = roaring64_bitmap_create();
  if (bm == NULL)
    luaL_error(L, "memory error creating bitmap");
  roaring64_bitmap_t **bmp = (roaring64_bitmap_t **)
    lua_newuserdata(L, sizeof(roaring64_bitmap_t *));
  *bmp = bm;
  luaL_getmetatable(L, MT_BITMAP);
  lua_setmetatable(L, -2);
  kbitr_t itr;
  kb_itr_first(tokens, bpe->tokens, &itr);
  for (; kb_itr_valid(&itr); kb_itr_next(tokens, bpe->tokens, &itr))
    roaring64_bitmap_add(bm, kb_itr_key(tb_token_t, &itr).t);
  return 1;
}

static inline bool tb_bpe_top_pair (
  tb_bpe_t *bpe,
  tb_pair_t *pair,
  int *count
) {
  tb_pair_t topp;
  int topv = 0;
  for (khint_t k = 0; k < kh_end(bpe->freqs); k ++)
    if (kh_exist(bpe->freqs, k) && kh_value(bpe->freqs, k) > topv) {
      topp = kh_key(bpe->freqs, k);
      topv = kh_value(bpe->freqs, k);
    }
  if (topv == 0)
    return false;
  *pair = topp;
  *count = topv;
  return true;
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
  size_t len = strlen(a) + strlen(b);
  if (len > bpe->maxlen)
    bpe->maxlen = len;
  char *c = malloc(len + 1);
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
    if (tb_bpe_skipchar(corpus[i]) && i < len - 1 && tb_bpe_skipchar(corpus[i + 1]))
      continue;
    tmp[0] = tb_bpe_skipchar(corpus[i]) ? ' ' : corpus[i];
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
  tb_bpe_count_frequencies(bpe);
  if (bpe->next_id >= bpe->vocab)
    return 0;
  int target = bpe->vocab - bpe->next_id;
  while (bpe->next_id < target) {
    int count;
    tb_pair_t top;
    if (!tb_bpe_top_pair(bpe, &top, &count)) {
      break;
    } else if (top.a == 1 || top.b == 1) {
      khint_t k = kh_get(freqs, bpe->freqs, top);
      assert(k != kh_end(bpe->freqs));
      kh_del(freqs, bpe->freqs, k);
      continue;
    }
    int new = tb_bpe_new_token(bpe, top);
    tb_bpe_update_corpus(bpe, top, new);
    tb_bpe_count_frequencies(bpe);
  }
  lua_pushinteger(L, bpe->next_id * bpe->dimensions * bpe->buckets);
  return 1;
}

static luaL_Reg tb_mt_fns[] =
{
  { "train", tb_bpe_train },
  { "tokenize", tb_bpe_tokenize },
  { "parse", tb_bpe_parse },
  { "persist", tb_bpe_persist },
  { "destroy", tb_bpe_destroy },
  { NULL, NULL }
};

static inline int tb_bpe_create (lua_State *L)
{
  unsigned int vocab = tk_lua_fcheckunsigned(L, 1, "vocab");
  unsigned int wavelength = tk_lua_fcheckunsigned(L, 1, "wavelength");
  unsigned int dimensions = tk_lua_fcheckunsigned(L, 1, "dimensions");
  unsigned int buckets = tk_lua_fcheckunsigned(L, 1, "buckets");
  // TODO: Get nthreads
  if (!dimensions)
    luaL_error(L, "dimensions must be greater than 0");
  if (!buckets)
    luaL_error(L, "buckets must be greater than 0");
  if (!wavelength)
    luaL_error(L, "wavelength must be greater than 0");
  tb_bpe_t *bpe = lua_newuserdata(L, sizeof(tb_bpe_t));
  memset(bpe, 0, sizeof(tb_bpe_t));
  luaL_getmetatable(L, MT_TOKENIZER);
  lua_setmetatable(L, -2);
  kv_init(bpe->deletes);
  bpe->ids = kh_init(ids);
  bpe->strs = kh_init(strs);
  bpe->tokens = kb_init(tokens, KB_DEFAULT_SIZE);
  bpe->freqs = kh_init(freqs);
  bpe->next_id = 2;
  bpe->maxlen = 0;
  bpe->vocab = vocab;
  bpe->wavelength = wavelength;
  bpe->dimensions = dimensions;
  bpe->buckets = buckets;
  khint_t k; int a;
  char *sp = strdup(" ");
  k = kh_put(ids, bpe->ids, sp, &a);
  assert(a);
  kh_value(bpe->ids, k) = 1;
  k = kh_put(strs, bpe->strs, 1, &a);
  kh_value(bpe->strs, k) = sp;
  assert(a);
  lua_newtable(L);
  lua_pushvalue(L, -2);
  tk_lua_register(L, tb_mt_fns, 1);
  return 1;
}

static inline int tb_bpe_load (lua_State *L)
{
  // TODO: 2nd param currently ignored, will be used for n_threads
  lua_settop(L, 3);
  size_t len;
  const char *data = luaL_checklstring(L, 1, &len);
  bool isstr = lua_type(L, 3) == LUA_TBOOLEAN && lua_toboolean(L, 3);
  FILE *fh = isstr ? tk_lua_fmemopen(L, (char *) data, len, "r") : tk_lua_fopen(L, data, "r");
  tb_bpe_t *bpe = lua_newuserdata(L, sizeof(tb_bpe_t));
  memset(bpe, 0, sizeof(tb_bpe_t));
  luaL_getmetatable(L, MT_TOKENIZER);
  lua_setmetatable(L, -2);
  kv_init(bpe->deletes);
  bpe->ids = kh_init(ids);
  bpe->strs = kh_init(strs);
  bpe->tokens = kb_init(tokens, KB_DEFAULT_SIZE);
  bpe->freqs = kh_init(freqs);
  tk_lua_fread(L, &bpe->vocab, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &bpe->wavelength, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &bpe->dimensions, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &bpe->buckets, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &bpe->next_id, sizeof(int), 1, fh);
  tk_lua_fread(L, &bpe->maxlen, sizeof(size_t), 1, fh);
  khint_t nkeys;
  khint_t k;
  int absent;
  tk_lua_fread(L, (char *) &nkeys, sizeof(khint_t), 1, fh);
  for (khint_t i = 0; i < nkeys; i ++) {
    size_t len;
    tk_lua_fread(L, &len, sizeof(size_t), 1, fh);
    char tok[len + 1];
    tk_lua_fread(L, tok, len, 1, fh);
    tok[len] = 0;
    int id;
    tk_lua_fread(L, &id, sizeof(int), 1, fh);
    char *tokn = strdup(tok);
    k = kh_put(ids, bpe->ids, tokn, &absent);
    assert(absent == 1);
    kh_value(bpe->ids, k) = id;
    k = kh_put(strs, bpe->strs, id, &absent);
    assert(absent == 1);
    kh_value(bpe->strs, k) = tokn;
  }
  tk_lua_fclose(L, fh);
  lua_newtable(L);
  lua_pushvalue(L, -2);
  tk_lua_register(L, tb_mt_fns, 1);
  return 1;
}

static luaL_Reg tb_fns[] =
{
  { "create", tb_bpe_create },
  { "load", tb_bpe_load },
  { NULL, NULL }
};

int luaopen_tbhss_bpe (lua_State *L)
{
  lua_newtable(L);
  tk_lua_register(L, tb_fns, 0);
  luaL_newmetatable(L, MT_TOKENIZER);
  lua_pushcfunction(L, tb_bpe_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);
  return 1;
}
