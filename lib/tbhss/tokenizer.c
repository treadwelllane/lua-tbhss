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
#include "kvec.h"

#define MT_BITMAP "santoku_bitmap"
#define MT_TOKENIZER "santoku_tokenizer"

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

static inline int tk_lua_error (lua_State *L, const char *err)
{
  lua_pushstring(L, err);
  tk_lua_callmod(L, 1, 0, "santoku.error", "error");
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

static inline double tk_lua_checkposdouble (lua_State *L, int i)
{
  lua_Number l = luaL_checknumber(L, i);
  if (l < 0)
    luaL_error(L, "value can't be negative");
  return (double) l;
}

static inline double tk_lua_fcheckposdouble (lua_State *L, int i, char *field)
{
  lua_getfield(L, i, field);
  double n = tk_lua_checkposdouble(L, -1);
  lua_pop(L, 1);
  return n;
}

static inline void tk_lua_fchecktype (lua_State *L, int i, char *field, int t)
{
  lua_getfield(L, i, field);
  luaL_checktype(L, -1, t);
  lua_pop(L, 1);
}

static inline lua_Number tk_lua_fchecknumber (lua_State *L, int i, char *field)
{
  lua_getfield(L, i, field);
  lua_Number n = luaL_checknumber(L, -1);
  lua_pop(L, 1);
  return n;
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

KHASH_MAP_INIT_STR(ids, int);
KHASH_MAP_INIT_INT(strs, char *);
KHASH_MAP_INIT_INT(dfs, unsigned int);
KHASH_SET_INIT_INT(seen);

typedef khash_t(ids) tb_ids_t;
typedef khash_t(strs) tb_strs_t;
typedef khash_t(dfs) tb_df_t;
typedef khash_t(seen) tb_seen_t;
typedef kvec_t(int) tb_tokens_t;
typedef kvec_t(char) tb_token_t;

typedef struct {
  double max_df;
  unsigned int min_len;
  unsigned int ndocs;
  unsigned int wavelength;
  unsigned int dimensions;
  unsigned int buckets;
  int next_id;
  size_t maxlen;
  tb_ids_t *ids;
  tb_strs_t *strs;
  tb_df_t *dfs;
  tb_seen_t *tmp_seen;
  tb_tokens_t tokens;
  tb_token_t tmp_token;
  bool collected;
  bool finalized;
} tb_tokenizer_t;

static tb_tokenizer_t *peek_tokenizer (lua_State *L, int i)
{
  return (tb_tokenizer_t *) luaL_checkudata(L, i, MT_TOKENIZER);
}

static inline int tb_tokenizer_gc (lua_State *L)
{
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, 1);
  if (tokenizer->collected)
    return 0;
  tokenizer->collected = true;
  for (khint_t k = kh_begin(tokenizer->strs); k < kh_end(tokenizer->strs); k ++)
    if (kh_exist(tokenizer->strs, k))
      free((char *) kh_value(tokenizer->strs, k));
  kv_destroy(tokenizer->tokens);
  kv_destroy(tokenizer->tmp_token);
  kh_destroy(ids, tokenizer->ids);
  kh_destroy(strs, tokenizer->strs);
  if (!tokenizer->finalized) {
    kh_destroy(dfs, tokenizer->dfs);
    kh_destroy(seen, tokenizer->tmp_seen);
  }
  return 0;
}

static inline int tb_tokenizer_destroy (lua_State *L)
{
  lua_settop(L, 0);
  lua_pushvalue(L, lua_upvalueindex(1));
  return tb_tokenizer_gc(L);
}

static inline int tb_tokenizer_persist (lua_State *L)
{
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, lua_upvalueindex(1));
  lua_settop(L, 1);
  bool tostr = lua_type(L, 1) == LUA_TNIL;
  FILE *fh;
  if (tostr)
    fh = tk_lua_tmpfile(L);
  else
    fh = tk_lua_fopen(L, luaL_checkstring(L, 1), "w");
  tk_lua_fwrite(L, (char *) &tokenizer->finalized, sizeof(bool), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->max_df, sizeof(double), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->min_len, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->ndocs, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->wavelength, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->dimensions, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->buckets, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->next_id, sizeof(int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->maxlen, sizeof(size_t), 1, fh);
  tk_lua_fwrite(L, (char *) &kh_size(tokenizer->ids), sizeof(khint_t), 1, fh);
  for (khint_t i = kh_begin(tokenizer->ids); i < kh_end(tokenizer->ids); i ++)
    if (kh_exist(tokenizer->ids, i)) {
      char *tok = (char *) kh_key(tokenizer->ids, i);
      size_t len = strlen(tok);
      int id = kh_value(tokenizer->ids, i) ;
      tk_lua_fwrite(L, (char *) &len, sizeof(size_t), 1, fh);
      tk_lua_fwrite(L, tok, len, 1, fh);
      tk_lua_fwrite(L, (char *) &id, sizeof(int), 1, fh);
    }
  if (!tokenizer->finalized) {
    tk_lua_fwrite(L, (char *) &kh_size(tokenizer->dfs), sizeof(khint_t), 1, fh);
    for (khint_t i = kh_begin(tokenizer->dfs); i < kh_end(tokenizer->dfs); i ++)
      if (kh_exist(tokenizer->dfs, i)) {
        int id = kh_key(tokenizer->dfs, i);
        int df = kh_value(tokenizer->dfs, i);
        tk_lua_fwrite(L, (char *) &id, sizeof(unsigned int), 1, fh);
        tk_lua_fwrite(L, (char *) &df, sizeof(unsigned int), 1, fh);
      }
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

static inline bool tb_tokenizer_skipchar (char c) {
  return !isalpha(c);
}

static inline const char *tb_tokenizer_id_str (
  tb_tokenizer_t *tokenizer,
  int id
) {
  khint_t k = kh_get(strs, tokenizer->strs, id);
  assert(k != kh_end(tokenizer->strs));
  return kh_value(tokenizer->strs, k);
}

static inline const int tb_tokenizer_str_id (
  tb_tokenizer_t *tokenizer,
  const char *str
) {
  khint_t k = kh_get(ids, tokenizer->ids, str);
  assert(k != kh_end(tokenizer->ids));
  return kh_value(tokenizer->ids, k);
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

static inline int tb_tokenizer_new_token (
  tb_tokenizer_t *tokenizer,
  const char *tok,
  size_t len
) {
  if (len > tokenizer->maxlen)
    tokenizer->maxlen = len;
  char *tokn = strdup(tok);
  int absent;
  khint_t k;
  k = kh_put(ids, tokenizer->ids, tokn, &absent);
  assert(absent == 1);
  int id = tokenizer->next_id ++;
  kh_value(tokenizer->ids, k) = id;
  k = kh_put(strs, tokenizer->strs, id, &absent);
  assert(absent == 1);
  kh_value(tokenizer->strs, k) = tokn;
  return id;
}

static inline void tb_tokenizer_populate_tokens (
  tb_tokenizer_t *tokenizer,
  const char *doc,
  size_t len,
  bool train
) {
  khint_t k;
  int id, absent;
  char *tok, *tokn;
  kh_clear(seen, tokenizer->tmp_seen);
  kv_size(tokenizer->tmp_token) = 0;
  kv_size(tokenizer->tokens) = 0;
  for (size_t e = 0; e <= len; e ++) {
    if (e < len && !tb_tokenizer_skipchar(doc[e])) {
      kv_push(char, tokenizer->tmp_token, tolower(doc[e]));
    } else if (kv_size(tokenizer->tmp_token) >= tokenizer->min_len) {
      kv_push(char, tokenizer->tmp_token, 0);
      tok = tokenizer->tmp_token.a;
      k = kh_get(ids, tokenizer->ids, tok);
      if (k != kh_end(tokenizer->ids)) {
        kv_push(int, tokenizer->tokens, kh_value(tokenizer->ids, k));
        kv_size(tokenizer->tmp_token) = 0;
        if (train) {
          id = kh_value(tokenizer->ids, k);
          k = kh_put(seen, tokenizer->tmp_seen, id, &absent);
          if (absent) {
            k = kh_put(dfs, tokenizer->dfs, id, &absent);
            kh_value(tokenizer->dfs, k) = (absent ? 0 : kh_value(tokenizer->dfs, k)) + 1;
          }
        }
      } else if (train) {
        tokn = strdup(tok);
        id = tokenizer->next_id ++;
        kv_push(int, tokenizer->tokens, id);
        kv_size(tokenizer->tmp_token) = 0;
        k = kh_put(ids, tokenizer->ids, tokn, &absent);
        assert(absent);
        kh_value(tokenizer->ids, k) = id;
        k = kh_put(strs, tokenizer->strs, id, &absent);
        assert(absent);
        kh_value(tokenizer->strs, k) = tokn;
        k = kh_put(seen, tokenizer->tmp_seen, id, &absent);
        assert(absent);
        k = kh_put(dfs, tokenizer->dfs, id, &absent);
        kh_value(tokenizer->dfs, k) = (absent ? 0 : kh_value(tokenizer->dfs, k)) + 1;
      } else {
        kv_push(int, tokenizer->tokens, 0);
        kv_size(tokenizer->tmp_token) = 0;
      }
    } else {
      kv_size(tokenizer->tmp_token) = 0;
    }
  }
}

static inline void _tb_tokenizer_parse (lua_State *L, tb_tokenizer_t *tokenizer)
{
  size_t len;
  const char *doc = luaL_checklstring(L, 1, &len);
  tb_tokenizer_populate_tokens(tokenizer, doc, len, false);
  khint_t k;
  lua_Integer n = 1;
  lua_newtable(L);
  for (khint_t i = 0; i < kv_size(tokenizer->tokens); i ++) {
    int t = kv_A(tokenizer->tokens, i);
    k = kh_get(strs, tokenizer->strs, t);
    if (k != kh_end(tokenizer->strs)) {
      lua_pushinteger(L, n);
      lua_pushstring(L, kh_value(tokenizer->strs, k));
      lua_settable(L, -3);
      n = n + 1;
    }
  }
}

static inline void _tb_tokenizer_tokenize (lua_State *L, tb_tokenizer_t *tokenizer)
{
  size_t len;
  const char *doc = luaL_checklstring(L, -1, &len); // s
  tb_tokenizer_populate_tokens(tokenizer, doc, len, false);
  roaring64_bitmap_t *bm = roaring64_bitmap_create();
  if (bm == NULL)
    luaL_error(L, "memory error creating bitmap");
  roaring64_bitmap_t **bmp = (roaring64_bitmap_t **) // s bm
    lua_newuserdata(L, sizeof(roaring64_bitmap_t *));
  *bmp = bm;
  luaL_getmetatable(L, MT_BITMAP); // s bm mt
  lua_setmetatable(L, -2); // s bm
  for (khint_t i = 0; i < kv_size(tokenizer->tokens); i ++)
    roaring64_bitmap_add(bm, kv_A(tokenizer->tokens, i));
}

static inline int tb_tokenizer_parse (lua_State *L)
{
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, lua_upvalueindex(1));
  lua_settop(L, 1);
  if (lua_type(L, 1) != LUA_TTABLE) {
    _tb_tokenizer_parse(L, tokenizer);
  } else {
    for (lua_Integer i = 1; i <= lua_objlen(L, 1); i ++) {
      lua_pushinteger(L, i); // t n
      lua_gettable(L, -2); // t s
      _tb_tokenizer_parse(L, tokenizer); // t s tt
      lua_pushinteger(L, i); // t s tt n
      lua_replace(L, -3); // t n tt
      lua_settable(L, -3); // t
    }
  }
  return 1;
}

static inline int tb_tokenizer_tokenize (lua_State *L)
{
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, lua_upvalueindex(1));
  lua_settop(L, 1);
  if (lua_type(L, 1) != LUA_TTABLE) {
    _tb_tokenizer_tokenize(L, tokenizer);
  } else {
    for (lua_Integer i = 1; i <= lua_objlen(L, 1); i ++) {
      lua_pushinteger(L, i); // t n
      lua_gettable(L, -2); // t s
      _tb_tokenizer_tokenize(L, tokenizer); // t s bm
      lua_pushinteger(L, i); // t s bm n
      lua_replace(L, -3); // t n bm
      lua_settable(L, -3); // t
    }
  }
  return 1;
}

static inline int tb_tokenizer_finalize (lua_State *L)
{
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, lua_upvalueindex(1));

  if (tokenizer->finalized)
    return 0;

  tokenizer->finalized = true;

  char *tok;
  double df;
  int id, id0, absent;
  khint_t i, k;
  tb_ids_t *ids0 = kh_init(ids);
  tb_strs_t *strs0 = kh_init(strs);

  // Delete tokens with df > max_df
  for (i = kh_begin(tokenizer->ids); i < kh_end(tokenizer->ids); i ++)
    if (kh_exist(tokenizer->ids, i)) {
      tok = (char *) kh_key(tokenizer->ids, i);
      id = kh_value(tokenizer->ids, i);
      k = kh_get(dfs, tokenizer->dfs, id);
      assert(k != kh_end(tokenizer->dfs));
      df = kh_value(tokenizer->dfs, k);
      if ((df / (double) tokenizer->ndocs) > tokenizer->max_df) {
        kh_del(ids, tokenizer->ids, i);
        k = kh_get(strs, tokenizer->strs, id);
        assert(k != kh_end(tokenizer->strs));
        kh_del(strs, tokenizer->strs, k);
        free(tok);
      }
    }
  kh_destroy(dfs, tokenizer->dfs);
  tokenizer->dfs = NULL;
  kh_destroy(seen, tokenizer->tmp_seen);
  tokenizer->tmp_seen = NULL;

  // Renumber tokens
  tokenizer->next_id = 1;
  for (i = kh_begin(tokenizer->ids); i < kh_end(tokenizer->ids); i ++)
    if (kh_exist(tokenizer->ids, i)) {
      tok = (char *) kh_key(tokenizer->ids, i);
      id = kh_value(tokenizer->ids, i);
      id0 = tokenizer->next_id ++;
      k = kh_put(ids, ids0, tok, &absent);
      assert(absent);
      kh_value(ids0, k) = id0;
      k = kh_put(strs, strs0, id0, &absent);
      assert(absent);
      kh_value(strs0, k) = tok;
    }

  kh_destroy(ids, tokenizer->ids);
  kh_destroy(strs, tokenizer->strs);
  tokenizer->ids = ids0;
  tokenizer->strs = strs0;

  return 0;
}

static inline int tb_tokenizer_features (lua_State *L)
{
  lua_settop(L, 1);
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, lua_upvalueindex(1));
  lua_pushinteger(L, tokenizer->next_id * tokenizer->dimensions * tokenizer->buckets);
  return 1;
}

static inline int tb_tokenizer_train (lua_State *L)
{
  lua_settop(L, 1);
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, lua_upvalueindex(1));
  if (tokenizer->finalized)
    return tk_lua_error(L, "already finalized");
  tk_lua_fchecktype(L, 1, "corpus", LUA_TTABLE);
  lua_getfield(L, 1, "corpus");
  lua_remove(L, 1);
  unsigned int n = lua_objlen(L, 1);
  for (unsigned int i = 1; i <= n; i ++) {
    lua_pushinteger(L, i);
    lua_gettable(L, -2);
    size_t len;
    const char *doc = luaL_checklstring(L, -1, &len);
    tb_tokenizer_populate_tokens(tokenizer, doc, len, true);
    lua_pop(L, 1);
    tokenizer->ndocs ++;
  }
  return 0;
}

static luaL_Reg tb_mt_fns[] =
{
  { "train", tb_tokenizer_train },
  { "tokenize", tb_tokenizer_tokenize },
  { "parse", tb_tokenizer_parse },
  { "features", tb_tokenizer_features },
  { "finalize", tb_tokenizer_finalize },
  { "persist", tb_tokenizer_persist },
  { "destroy", tb_tokenizer_destroy },
  { NULL, NULL }
};

static inline int tb_tokenizer_create (lua_State *L)
{
  double max_df = tk_lua_fcheckposdouble(L, 1, "max_df");
  unsigned int min_len = tk_lua_fcheckunsigned(L, 1, "min_len");
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
  tb_tokenizer_t *tokenizer = lua_newuserdata(L, sizeof(tb_tokenizer_t));
  memset(tokenizer, 0, sizeof(tb_tokenizer_t));
  luaL_getmetatable(L, MT_TOKENIZER);
  lua_setmetatable(L, -2);
  kv_init(tokenizer->tokens);
  kv_init(tokenizer->tmp_token);
  tokenizer->ids = kh_init(ids);
  tokenizer->strs = kh_init(strs);
  tokenizer->dfs = kh_init(dfs);
  tokenizer->tmp_seen = kh_init(seen);
  tokenizer->next_id = 1;
  tokenizer->maxlen = 0;
  tokenizer->ndocs = 0;
  tokenizer->max_df = max_df;
  tokenizer->min_len = min_len;
  tokenizer->wavelength = wavelength;
  tokenizer->dimensions = dimensions;
  tokenizer->buckets = buckets;
  lua_newtable(L);
  lua_pushvalue(L, -2);
  tk_lua_register(L, tb_mt_fns, 1);
  return 1;
}

static inline int tb_tokenizer_load (lua_State *L)
{
  // TODO: 2nd param currently ignored, will be used for n_threads
  lua_settop(L, 3);
  size_t len;
  const char *data = luaL_checklstring(L, 1, &len);
  bool isstr = lua_type(L, 3) == LUA_TBOOLEAN && lua_toboolean(L, 3);
  FILE *fh = isstr ? tk_lua_fmemopen(L, (char *) data, len, "r") : tk_lua_fopen(L, data, "r");
  tb_tokenizer_t *tokenizer = lua_newuserdata(L, sizeof(tb_tokenizer_t));
  memset(tokenizer, 0, sizeof(tb_tokenizer_t));
  luaL_getmetatable(L, MT_TOKENIZER);
  lua_setmetatable(L, -2);
  kv_init(tokenizer->tokens);
  kv_init(tokenizer->tmp_token);
  tokenizer->ids = kh_init(ids);
  tokenizer->strs = kh_init(strs);
  tokenizer->dfs = kh_init(dfs);
  tokenizer->tmp_seen = kh_init(seen);
  tk_lua_fread(L, &tokenizer->finalized, sizeof(bool), 1, fh);
  tk_lua_fread(L, &tokenizer->max_df, sizeof(double), 1, fh);
  tk_lua_fread(L, &tokenizer->min_len, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->ndocs, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->wavelength, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->dimensions, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->buckets, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->next_id, sizeof(int), 1, fh);
  tk_lua_fread(L, &tokenizer->maxlen, sizeof(size_t), 1, fh);
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
    k = kh_put(ids, tokenizer->ids, tokn, &absent);
    assert(absent == 1);
    kh_value(tokenizer->ids, k) = id;
    k = kh_put(strs, tokenizer->strs, id, &absent);
    assert(absent == 1);
    kh_value(tokenizer->strs, k) = tokn;
  }
  if (!tokenizer->finalized) {
    tk_lua_fread(L, (char *) &nkeys, sizeof(khint_t), 1, fh);
    for (khint_t i = 0; i < nkeys; i ++) {
      int id;
      unsigned int df;
      tk_lua_fread(L, &id, sizeof(int), 1, fh);
      tk_lua_fread(L, &df, sizeof(unsigned int), 1, fh);
      k = kh_put(dfs, tokenizer->dfs, id, &absent);
      assert(absent == 1);
      kh_value(tokenizer->ids, k) = df;
    }
  }
  tk_lua_fclose(L, fh);
  lua_newtable(L);
  lua_pushvalue(L, -2);
  tk_lua_register(L, tb_mt_fns, 1);
  return 1;
}

static luaL_Reg tb_fns[] =
{
  { "create", tb_tokenizer_create },
  { "load", tb_tokenizer_load },
  { NULL, NULL }
};

int luaopen_tbhss_tokenizer (lua_State *L)
{
  lua_newtable(L);
  tk_lua_register(L, tb_fns, 0);
  luaL_newmetatable(L, MT_TOKENIZER);
  lua_pushcfunction(L, tb_tokenizer_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);
  return 1;
}
