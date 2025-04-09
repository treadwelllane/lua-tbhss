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
  size_t r = fread(data, size, memb, fh);
  if (!(ferror(fh) || r < memb)) return;
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

typedef struct {
  unsigned int id;
  unsigned int df;
} tk_sort_pair_t;

static inline int tk_sort_pair_cmp (tk_sort_pair_t a, tk_sort_pair_t b)
{
  return (int) (a.df < b.df) - (int) (b.df < a.df);
}

KBTREE_INIT(sort, tk_sort_pair_t, tk_sort_pair_cmp);
KHASH_MAP_INIT_STR(ids, int);
KHASH_MAP_INIT_INT(strs, char *);
KHASH_MAP_INIT_INT(dfs, unsigned int);
KHASH_SET_INIT_INT(seen);

typedef kbtree_t(sort) tb_sort_t;
typedef khash_t(ids) tb_ids_t;
typedef khash_t(strs) tb_strs_t;
typedef khash_t(dfs) tb_df_t;
typedef khash_t(seen) tb_seen_t;
typedef kvec_t(int) tb_tokens_t;
typedef kvec_t(char) tb_token_t;

typedef struct {
  double max_df;
  double min_df;
  unsigned int max_len;
  unsigned int min_len;
  unsigned int ngrams;
  unsigned int cgrams;
  unsigned int ndocs;
  int next_id;
  size_t max_len_observed;
  tb_ids_t *ids;
  tb_strs_t *strs;
  tb_df_t *dfs;
  tb_seen_t *tmp_seen;
  tb_tokens_t tokens;
  tb_tokens_t ngram;
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
  kv_destroy(tokenizer->ngram);
  kh_destroy(ids, tokenizer->ids);
  kh_destroy(strs, tokenizer->strs);
  if (tokenizer->dfs)
    kh_destroy(dfs, tokenizer->dfs);
  if (tokenizer->tmp_seen)
    kh_destroy(seen, tokenizer->tmp_seen);
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
  tk_lua_fwrite(L, (char *) &tokenizer->min_df, sizeof(double), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->max_len, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->min_len, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->ngrams, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->cgrams, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->ndocs, sizeof(unsigned int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->next_id, sizeof(int), 1, fh);
  tk_lua_fwrite(L, (char *) &tokenizer->max_len_observed, sizeof(size_t), 1, fh);
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

static inline char *tb_tokenizer_id_str (
  tb_tokenizer_t *tokenizer,
  int id
) {
  khint_t k = kh_get(strs, tokenizer->strs, id);
  assert(k != kh_end(tokenizer->strs));
  return (char *) kh_value(tokenizer->strs, k);
}

static inline int tb_tokenizer_str_id (
  tb_tokenizer_t *tokenizer,
  char *str
) {
  khint_t k = kh_get(ids, tokenizer->ids, str);
  assert(k != kh_end(tokenizer->ids));
  return kh_value(tokenizer->ids, k);
}

static inline int tb_tokenizer_new_token (
  tb_tokenizer_t *tokenizer,
  char **tokp,
  bool train
) {
  char *tok = *tokp;
  size_t len = strlen(tok);
  int id, absent;
  khint_t k = kh_get(ids, tokenizer->ids, tok);
  if (k != kh_end(tokenizer->ids)) {
    id = kh_value(tokenizer->ids, k);
    *tokp = (char *) kh_key(tokenizer->ids, k);
  } else if (!train) {
    return -1;
  } else {
    if (len > tokenizer->max_len_observed)
      tokenizer->max_len_observed = len;
    *tokp = strndup(tok, len);
    id = tokenizer->next_id ++;
    k = kh_put(ids, tokenizer->ids, *tokp, &absent);
    assert(absent);
    kh_value(tokenizer->ids, k) = id;
    k = kh_put(strs, tokenizer->strs, id, &absent);
    assert(absent);
    kh_value(tokenizer->strs, k) = *tokp;
  }
  if (train) {
    k = kh_put(seen, tokenizer->tmp_seen, id, &absent);
    if (absent) {
      k = kh_put(dfs, tokenizer->dfs, id, &absent);
      kh_value(tokenizer->dfs, k) = (absent ? 0 : kh_value(tokenizer->dfs, k)) + 1;
    }
  }
  return id;
}

static inline void tb_tokenizer_append_cgrams (
  tb_tokenizer_t *tokenizer,
  char *tok,
  bool train
) {
  if (tokenizer->cgrams == 0)
    return;

  size_t len = strlen(tok);

  if (len <= tokenizer->cgrams)
    return;

  char tmp[tokenizer->cgrams + 1];

  size_t s = 0;
  size_t e = 0 + tokenizer->cgrams - 1;

  while (e < len)
  {
    for (unsigned int i = 0; i < tokenizer->cgrams; i ++) {
      tmp[i] = tok[s + i];
      tmp[i + 1] = 0;
      char *tmpp = tmp;
      if (strlen(tmp) < tokenizer->min_len)
        continue;
      int id = tb_tokenizer_new_token(tokenizer, &tmpp, train);
      if (id == -1)
        continue;
      kv_push(int, tokenizer->tokens, id);
    }

    s ++;
    e ++;
  }
}

static inline void tb_tokenizer_append_token (
  tb_tokenizer_t *tokenizer,
  char *tok,
  bool train
) {
  int id = tb_tokenizer_new_token(tokenizer, &tok, train);

  if (id == -1)
    return;

  tb_tokenizer_append_cgrams(tokenizer, tok, train);

  if (kv_size(tokenizer->ngram) == tokenizer->ngrams) {
    for (khint_t i = 1; i < kv_size(tokenizer->ngram); i++)
      kv_A(tokenizer->ngram, i - 1) = kv_A(tokenizer->ngram, i);
    kv_size(tokenizer->ngram)--;
  }

  kv_push(int, tokenizer->ngram, id);

  char tmp[tokenizer->max_len_observed * tokenizer->ngrams + tokenizer->ngrams];
  char *tmps[tokenizer->ngrams + 1];
  tmps[0] = tmp;
  for (khint_t i = 0; i < kv_size(tokenizer->ngram); i ++) {
    tok = tb_tokenizer_id_str(tokenizer, kv_A(tokenizer->ngram, i));
    size_t tokl = strlen(tok);
    memcpy(tmps[i], tok, tokl);
    tmps[i][tokl] = (i + 1 == kv_size(tokenizer->ngram)) ? '\0' : ' ';
    tmps[i + 1] = tmps[i] + tokl + 1;
  }

  for (khint_t i = 0; i < kv_size(tokenizer->ngram); i ++) {
    char *tok = tmps[i];
    char *tokp = tok;
    id = tb_tokenizer_new_token(tokenizer, &tokp, train);
    kv_push(int, tokenizer->tokens, id);
  }
}

static inline void tb_tokenizer_populate_tokens (
  tb_tokenizer_t *tokenizer,
  const char *doc,
  size_t len,
  bool train
) {
  bool skipping = false;
  kh_clear(seen, tokenizer->tmp_seen);
  kv_size(tokenizer->tmp_token) = 0;
  kv_size(tokenizer->tokens) = 0;
  kv_size(tokenizer->ngram) = 0;
  for (size_t e = 0; e <= len; e ++) {
    if (skipping && !tb_tokenizer_skipchar(doc[e]))
      continue;
    if (skipping && tb_tokenizer_skipchar(doc[e]))
      skipping = false;
    if (e < len && !tb_tokenizer_skipchar(doc[e])) {
      kv_push(char, tokenizer->tmp_token, tolower(doc[e]));
      if (kv_size(tokenizer->tmp_token) > tokenizer->max_len) {
        kv_size(tokenizer->tmp_token) = 0;
        skipping = true;
      }
    } else if (kv_size(tokenizer->tmp_token) >= tokenizer->min_len) {
      kv_push(char, tokenizer->tmp_token, 0);
      tb_tokenizer_append_token(tokenizer, tokenizer->tmp_token.a, train);
      kv_size(tokenizer->tmp_token) = 0;
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
  lua_Integer n = 1;
  lua_newtable(L);
  for (khint_t i = 0; i < kv_size(tokenizer->tokens); i ++) {
    lua_pushinteger(L, n ++);
    int t = kv_A(tokenizer->tokens, i);
    lua_pushstring(L, tb_tokenizer_id_str(tokenizer, t));
    lua_settable(L, -3);
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
    if (kv_A(tokenizer->tokens, i) >= 0)
      roaring64_bitmap_add(bm, kv_A(tokenizer->tokens, i));
}

static inline int tb_tokenizer_parse (lua_State *L)
{
  tb_tokenizer_t *tokenizer = peek_tokenizer(L, lua_upvalueindex(1));
  lua_settop(L, 1);
  if (lua_type(L, 1) != LUA_TTABLE) {
    _tb_tokenizer_parse(L, tokenizer);
  } else {
    for (size_t i = 1; i <= lua_objlen(L, 1); i ++) {
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
    for (size_t i = 1; i <= lua_objlen(L, 1); i ++) {
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
    return luaL_error(L, "already finalized");;

  tokenizer->finalized = true;

  char *tok;
  double df;
  int id, id0, absent;
  khint_t i, k;
  tb_ids_t *ids0 = kh_init(ids);
  tb_strs_t *strs0 = kh_init(strs);

  tb_sort_t *sort = kb_init(sort, KB_DEFAULT_SIZE);

  // Delete tokens with df > max_df
  for (i = kh_begin(tokenizer->ids); i < kh_end(tokenizer->ids); i ++)
    if (kh_exist(tokenizer->ids, i)) {
      tok = (char *) kh_key(tokenizer->ids, i);
      id = kh_value(tokenizer->ids, i);
      k = kh_get(dfs, tokenizer->dfs, id);
      assert(k != kh_end(tokenizer->dfs));
      df = (double) kh_value(tokenizer->dfs, k) / (double) tokenizer->ndocs;
      if (df > tokenizer->max_df || df < tokenizer->min_df) {
        kh_del(ids, tokenizer->ids, i);
        k = kh_get(strs, tokenizer->strs, id);
        assert(k != kh_end(tokenizer->strs));
        kh_del(strs, tokenizer->strs, k);
        free(tok);
      } else {
        tk_sort_pair_t p = { .id = id, .df = df };
        kb_put(sort, sort, p);
      }
    }
  kh_destroy(dfs, tokenizer->dfs);
  tokenizer->dfs = NULL;
  kh_destroy(seen, tokenizer->tmp_seen);
  tokenizer->tmp_seen = NULL;

  // Renumber tokens
  tokenizer->next_id = 0;
  kbitr_t itr;
  kb_itr_first(sort, sort, &itr);
  for (; kb_itr_valid(&itr); kb_itr_next(sort, sort, &itr)) {
    id = kb_itr_key(tk_sort_pair_t, &itr).id;
    k = kh_get(strs, tokenizer->strs, id);
    assert(k != kh_end(tokenizer->strs));
    tok = (char *) kh_value(tokenizer->strs, k);
    id0 = tokenizer->next_id ++;
    k = kh_put(ids, ids0, tok, &absent);
    assert(absent);
    kh_value(ids0, k) = id0;
    k = kh_put(strs, strs0, id0, &absent);
    assert(absent);
    kh_value(strs0, k) = tok;
  }

  kb_destroy(sort, sort);
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
  lua_pushinteger(L, tokenizer->next_id);
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
  double min_df = tk_lua_fcheckposdouble(L, 1, "min_df");
  unsigned int max_len = tk_lua_fcheckunsigned(L, 1, "max_len");
  unsigned int min_len = tk_lua_fcheckunsigned(L, 1, "min_len");
  unsigned int ngrams = tk_lua_fcheckunsigned(L, 1, "ngrams");
  unsigned int cgrams = tk_lua_fcheckunsigned(L, 1, "cgrams");
  // TODO: Get nthreads
  if (min_df < 0 || max_df > 1 || max_df < min_df)
    luaL_error(L, "min_df and max_df must be an interval between 0 and 1");
  if (min_len == 0)
    luaL_error(L, "min_len must be greater than or equal to 1");
  if (max_len < min_len)
    luaL_error(L, "max_len must be greater than or equal to min_len");
  if (ngrams == 0)
    luaL_error(L, "ngrams must be greater than or equal to 1");
  tb_tokenizer_t *tokenizer = lua_newuserdata(L, sizeof(tb_tokenizer_t));
  memset(tokenizer, 0, sizeof(tb_tokenizer_t));
  luaL_getmetatable(L, MT_TOKENIZER);
  lua_setmetatable(L, -2);
  kv_init(tokenizer->tokens);
  kv_init(tokenizer->tmp_token);
  kv_init(tokenizer->ngram);
  tokenizer->ids = kh_init(ids);
  tokenizer->strs = kh_init(strs);
  tokenizer->dfs = kh_init(dfs);
  tokenizer->tmp_seen = kh_init(seen);
  tokenizer->next_id = 0;
  tokenizer->max_len_observed = 0;
  tokenizer->ndocs = 0;
  tokenizer->max_df = max_df;
  tokenizer->min_df = min_df;
  tokenizer->max_len = max_len;
  tokenizer->min_len = min_len;
  tokenizer->ngrams = ngrams;
  tokenizer->cgrams = cgrams;
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
  kv_init(tokenizer->ngram);
  tokenizer->ids = kh_init(ids);
  tokenizer->strs = kh_init(strs);
  if (!tokenizer->finalized) {
    tokenizer->dfs = kh_init(dfs);
    tokenizer->tmp_seen = kh_init(seen);
  }
  tk_lua_fread(L, &tokenizer->finalized, sizeof(bool), 1, fh);
  tk_lua_fread(L, &tokenizer->max_df, sizeof(double), 1, fh);
  tk_lua_fread(L, &tokenizer->min_df, sizeof(double), 1, fh);
  tk_lua_fread(L, &tokenizer->max_len, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->min_len, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->ngrams, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->cgrams, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->ndocs, sizeof(unsigned int), 1, fh);
  tk_lua_fread(L, &tokenizer->next_id, sizeof(int), 1, fh);
  tk_lua_fread(L, &tokenizer->max_len_observed, sizeof(size_t), 1, fh);
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
    assert(absent);
    kh_value(tokenizer->ids, k) = id;
    k = kh_put(strs, tokenizer->strs, id, &absent);
    assert(absent);
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
      assert(absent);
      kh_value(tokenizer->dfs, k) = df;
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
