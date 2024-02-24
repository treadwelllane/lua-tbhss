#include "lua.h"
#include "lauxlib.h"

#include <math.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>

#define TK_TSETLIN_MT "santoku_tsetlin"
#define TK_TSETLIN_UPVALUE_BRAW 1

typedef struct {

  lua_Integer features;
  lua_Integer clauses;
  lua_Integer state_bits;
  lua_Number threshold;
  bool boost_true_positive;

  lua_Integer filter;
  lua_Integer la_chunks;
  lua_Integer clause_chunks;

  lua_Integer mask01;
  lua_Integer mask10;

  lua_Integer *automata_states;
  lua_Integer *clause_outputs;
  lua_Integer *clause_feedback;
  lua_Integer *la_feedback;

} tk_tsetlin_t;

#define TK_TSETLIN_FAST_RAND_MAX UINT32_MAX
uint64_t const tk_tsetlin_rand_multiplier = 6364136223846793005u;
uint64_t tk_tsetlin_rand_state = 0xcafef00dd15ea5e5u;
uint32_t tk_tsetlin_fast_rand () {
  uint64_t x = tk_tsetlin_rand_state;
  uint32_t count = (uint32_t) (x >> 61);
  tk_tsetlin_rand_state = x * tk_tsetlin_rand_multiplier;
  return (uint32_t) ((x ^ x >> 22) >> (22 + count));
}

lua_Integer tk_tsetlin_rand_normal (lua_Number mean, lua_Number variance) {
  lua_Number u1 = (lua_Number) (tk_tsetlin_fast_rand() + 1) / ((lua_Number) TK_TSETLIN_FAST_RAND_MAX + 1);
  lua_Number u2 = (lua_Number) tk_tsetlin_fast_rand() / TK_TSETLIN_FAST_RAND_MAX;
  lua_Number n1 = sqrt(-2 * log(u1)) * sin(8 * atan(1) * u2);
  return (lua_Integer) round(mean + sqrt(variance) * n1);
}

#define tk_tsetlin_automata_idx(t, l, la, b) \
  (l * (t)->la_chunks * (t)->state_bits + la * (t)->state_bits + b)
// #define tk_tsetlin_automata_idx(t, f, l, p) (f + (l * (t)->features * 2) + (p ? (t)->features : 0))
// #define tk_tsetlin_clause_idx(t, l) (l)
// #define tk_tsetlin_action(t, n) (n > (t)->states)

tk_tsetlin_t **tk_tsetlin_peekp (lua_State *L, int i)
{
  return (tk_tsetlin_t **) luaL_checkudata(L, i, TK_TSETLIN_MT);
}

tk_tsetlin_t *tk_tsetlin_peek (lua_State *L, int i)
{
  return *tk_tsetlin_peekp(L, i);
}

int tk_tsetlin_destroy (lua_State *L)
{
  lua_settop(L, 1);
  tk_tsetlin_t **tmp = tk_tsetlin_peekp(L, 1);
  tk_tsetlin_t *tm = *tmp;
  if (tm == NULL)
    return 0;
  free(tm->automata_states);
  free(tm->clause_outputs);
  free(tm->clause_feedback);
  free(tm->la_feedback);
  tm->automata_states = NULL;
  tm->clause_outputs = NULL;
  tm->clause_feedback = NULL;
  tm->la_feedback = NULL;
  free(tm);
  *tmp = NULL;
  return 0;
}

void _tk_tsetlin_initialize (tk_tsetlin_t *tm)
{
  for (lua_Integer l = 0; l < tm->clauses; l ++) {
    for (lua_Integer la = 0; la < tm->la_chunks; la ++) {
      for (lua_Integer b = 0; b < tm->state_bits - 1; b ++)
        tm->automata_states[tk_tsetlin_automata_idx(tm, l, la, b)] = ~0;
      tm->automata_states[tk_tsetlin_automata_idx(tm, l, la, tm->state_bits - 1)] = 0;
    }
  }
}

void _tk_tsetlin_initialize_random_streams (tk_tsetlin_t *tm, lua_Number s)
{
	memset(tm->la_feedback, 0, sizeof(lua_Integer) * tm->la_chunks);
	lua_Integer n = 2 * tm->features;
	lua_Number p = 1.0 / s;
	lua_Integer active = tk_tsetlin_rand_normal(n * p, n * p * (1 - p));
	active = active >= n ? n : active;
	active = active < 0 ? 0 : active;
	while (active --) {
		lua_Integer f = tk_tsetlin_fast_rand() % (2 * tm->features);
    while (tm->la_feedback[f / sizeof(lua_Integer)] & (1 << (f % sizeof(lua_Integer))))
      f = tk_tsetlin_fast_rand() % (2 * tm->features);
		tm->la_feedback[f / sizeof(lua_Integer)] |= 1 << (f % sizeof(lua_Integer));
	}
}

void _tk_tsetlin_inc (tk_tsetlin_t *tm, lua_Integer l, lua_Integer la, lua_Integer active)
{
	lua_Integer carry, carry_next;
	carry = active;
	for (lua_Integer b = 0; b < tm->state_bits; b ++) {
		if (carry == 0)
			break;
    lua_Integer idx = tk_tsetlin_automata_idx(tm, l, la, b);
		carry_next = tm->automata_states[idx] & carry;
		tm->automata_states[idx] = tm->automata_states[idx] ^ carry;
		carry = carry_next;
	}
	if (carry > 0) {
		for (lua_Integer b = 0; b < tm->state_bits; b ++) {
      lua_Integer idx = tk_tsetlin_automata_idx(tm, l, la, b);
			tm->automata_states[idx] |= carry;
		}
	}
}

void _tk_tsetlin_dec (tk_tsetlin_t *tm, lua_Integer l, lua_Integer la, lua_Integer active)
{
	lua_Integer carry, carry_next;
	carry = active;
	for (lua_Integer b = 0; b < tm->state_bits; b ++) {
		if (carry == 0)
			break;
    lua_Integer idx = tk_tsetlin_automata_idx(tm, l, la, b);
		carry_next = (~tm->automata_states[idx]) & carry;
		tm->automata_states[idx] = tm->automata_states[idx] ^ carry;
		carry = carry_next;
	}
	if (carry > 0) {
		for (lua_Integer b = 0; b < tm->state_bits; b ++) {
      lua_Integer idx = tk_tsetlin_automata_idx(tm, l, la, b);
			tm->automata_states[idx] &= ~carry;
		}
	}
}

int tk_tsetlin_create (lua_State *L)
{
  tk_tsetlin_t *tm = (tk_tsetlin_t *) malloc(sizeof(tk_tsetlin_t));
  if (!tm)
    goto err_mem;

  lua_settop(L, 5);

  tm->features = luaL_checkinteger(L, 1);
  tm->clauses = luaL_checkinteger(L, 2);
  tm->state_bits = luaL_checkinteger(L, 3);
  tm->threshold = luaL_checknumber(L, 4);

  if (tm->state_bits > sizeof(lua_Integer) * CHAR_BIT)
    luaL_error(L, "too many state bits");

  luaL_checktype(L, 5, LUA_TBOOLEAN);
  tm->boost_true_positive = lua_toboolean(L, 5);

  tm->la_chunks = (2 * tm->features - 1) / sizeof(lua_Integer) + 1;
  tm->clause_chunks = (tm->clauses - 1) / sizeof(lua_Integer) + 1;

  if ((tm->features * 2) % sizeof(lua_Integer) != 0)
    tm->filter = ~(((lua_Integer) (~0)) << ((tm->features * 2) % sizeof(lua_Integer)));
  else
    tm->filter = (lua_Integer) (~0);

  tm->automata_states = malloc(sizeof(lua_Integer) * tm->clauses * tm->la_chunks * tm->state_bits);
  tm->clause_outputs = malloc(sizeof(lua_Integer) * tm->clause_chunks);
  tm->clause_feedback = malloc(sizeof(lua_Integer) * tm->clause_chunks);
  tm->la_feedback = malloc(sizeof(lua_Integer) * tm->la_chunks);

  if (!(tm->automata_states && tm->clause_outputs && tm->clause_feedback && tm->la_feedback))
    goto err_mem;

  tm->mask01 = 0;
  tm->mask10 = 0;

  for (lua_Integer i = 0; i < sizeof(lua_Integer) * CHAR_BIT; i ++)
    tm->mask01 |= 1 << (2 * i + 1);

  for (lua_Integer i = 0; i < sizeof(lua_Integer) * CHAR_BIT; i ++)
    tm->mask10 |= 1 << (2 * i);

  _tk_tsetlin_initialize(tm);

  tk_tsetlin_t **tmp = (tk_tsetlin_t **) lua_newuserdata(L, sizeof(tk_tsetlin_t *));
  *tmp = tm;

  luaL_getmetatable(L, TK_TSETLIN_MT);
  lua_setmetatable(L, -2);

  return 1;

err_mem:
  luaL_error(L, "Error in malloc during tsetlin create");
  return 0;
}

// TODO: Duplicated across various libraries, need to consolidate
void tk_tsetlin_import (lua_State *L, const char *smod, const char *sfn)
{
  lua_getglobal(L, "require"); // req
  lua_pushstring(L, smod); // req smod
  lua_call(L, 1, 1); // mod
  lua_pushstring(L, sfn); // mod sfn
  lua_gettable(L, -2); // mod fn
  lua_remove(L, -2); // fn
}

// TODO: Duplicated across various libraries, need to consolidate
void tk_tsetlin_callmod (lua_State *L, int nargs, int nret, const char *smod, const char *sfn)
{
  lua_getglobal(L, "require"); // arg req
  lua_pushstring(L, smod); // arg req smod
  lua_call(L, 1, 1); // arg mod
  lua_pushstring(L, sfn); // args mod sfn
  lua_gettable(L, -2); // args mod fn
  lua_remove(L, -2); // args fn
  lua_insert(L, - nargs - 1); // fn args
  lua_call(L, nargs, nret); // results
}

// TODO: Duplicated across various libraries, need to consolidate
void tk_tsetlin_callupvalue (lua_State *L, int nargs, int nret, int idx)
{
  lua_pushvalue(L, lua_upvalueindex(idx)); // args fn
  lua_insert(L, - nargs - 1); // fn args
  lua_call(L, nargs, nret); // results
}

void tk_tsetlin_register (lua_State *L, luaL_Reg *regs, int nup)
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

lua_Integer _tk_tsetlin_sum_class_votes (tk_tsetlin_t *tm)
{
	int class_sum = 0;
	for (lua_Integer cc = 0; cc < tm->clause_chunks; cc ++) {
		class_sum += __builtin_popcount(tm->clause_outputs[cc] & tm->mask01); // 0101
		class_sum -= __builtin_popcount(tm->clause_outputs[cc] & tm->mask10); // 1010
	}
	class_sum = (class_sum > tm->threshold) ? tm->threshold : class_sum;
	class_sum = (class_sum < -tm->threshold) ? -tm->threshold : class_sum;
	return class_sum;
}

void _tk_tsetlin_calculate_clause_output (tk_tsetlin_t *tm, lua_Integer *bm, bool predict)
{
	memset(tm->clause_outputs, 0, sizeof(lua_Integer) * tm->clause_chunks);
	for (int l = 0; l < tm->clauses; l ++) {
		bool output = 1;
		bool all_exclude = 1;
		for (int la = 0; la < tm->la_chunks - 1; la ++) {
      lua_Integer idx = tk_tsetlin_automata_idx(tm, l, la, tm->state_bits - 1);
			output = output && (tm->automata_states[idx] & bm[la]) == tm->automata_states[idx];
			if (!output)
				break;
			all_exclude = all_exclude && (tm->automata_states[idx] == 0);
		}
    lua_Integer idx = tk_tsetlin_automata_idx(tm, l, tm->la_chunks - 1, tm->state_bits - 1);
		output = output &&
			(tm->automata_states[idx] & bm[tm->la_chunks - 1] & tm->filter) ==
			(tm->automata_states[idx] & tm->filter);
		all_exclude = all_exclude && ((tm->automata_states[idx] & tm->filter) == 0);
		output = output && !(predict && all_exclude == 1);
		if (output) {
			lua_Integer clause_chunk = l / sizeof(lua_Integer);
			lua_Integer clause_chunk_pos = l % sizeof(lua_Integer);
 			tm->clause_outputs[clause_chunk] |= (1 << clause_chunk_pos);
 		}
 	}
}

void _tk_tsetlin_update (tk_tsetlin_t *tm, lua_Integer *bm, bool target, lua_Number s)
{
  target = target ? 1 : 0;
  _tk_tsetlin_calculate_clause_output(tm, bm, false);
  lua_Integer class_sum = _tk_tsetlin_sum_class_votes(tm);
  lua_Number p = (1.0 / (tm->threshold * 2)) * (tm->threshold + (1 - 2 * target) * class_sum);
  memset(tm->clause_feedback, 0, sizeof(lua_Integer) * tm->clause_chunks);
  for (int l = 0; l < tm->clauses; l ++) {
    lua_Integer clause_chunk = l / sizeof(lua_Integer);
    lua_Integer clause_chunk_pos = l % sizeof(lua_Integer);
    tm->clause_feedback[clause_chunk] |= (((lua_Number) tk_tsetlin_fast_rand()) / ((lua_Number) TK_TSETLIN_FAST_RAND_MAX) <= p) << clause_chunk_pos;
  }
	for (int l = 0; l < tm->clauses; l ++) {
    lua_Integer clause_chunk = l / sizeof(lua_Integer);
    lua_Integer clause_chunk_pos = l % sizeof(lua_Integer);
		if (!(tm->clause_feedback[clause_chunk] & (1 << clause_chunk_pos)))
			continue;
		if ((2 * target - 1) * (1 - 2 * (l & 1)) == -1) {
			if ((tm->clause_outputs[clause_chunk] & (1 << clause_chunk_pos)) > 0) {
				// Type II Feedback
				for (int la = 0; la < tm->la_chunks; la ++) {
          lua_Integer idx = tk_tsetlin_automata_idx(tm, l, la, tm->state_bits - 1);
					_tk_tsetlin_inc(tm, l, la, (~bm[la]) & (~tm->automata_states[idx]));
        }
			}
		} else if ((2 * target - 1) * (1 - 2 * (l & 1)) == 1) {
			// Type I Feedback
			_tk_tsetlin_initialize_random_streams(tm, s);
			if ((tm->clause_outputs[clause_chunk] & (1 << clause_chunk_pos)) > 0) {
        if (tm->boost_true_positive) {
          for (int la = 0; la < tm->la_chunks; la ++) {
            _tk_tsetlin_inc(tm, l, la, bm[la]);
            _tk_tsetlin_dec(tm, l, la, (~bm[la]) & tm->la_feedback[la]);
          }
        } else {
          for (int la = 0; la < tm->la_chunks; la ++) {
						_tk_tsetlin_inc(tm, l, la, bm[la] & (~tm->la_feedback[la]));
            _tk_tsetlin_dec(tm, l, la, (~bm[la]) & tm->la_feedback[la]);
          }
        }
			} else {
				for (int la = 0; la < tm->la_chunks; la ++) {
					_tk_tsetlin_dec(tm, l, la, tm->la_feedback[la]);
				}
			}
		}
	}
}

lua_Integer *tk_tsetlin_peek_raw_bitmap (lua_State *L, tk_tsetlin_t *tm, int i)
{
  luaL_checkudata(L, i, "santoku_bitmap");
  lua_pushvalue(L, i); // bm
  tk_tsetlin_callupvalue(L, 1, 2, TK_TSETLIN_UPVALUE_BRAW); // raw bits
  lua_Integer *raw = (lua_Integer *) lua_touserdata(L, -2);
  lua_Integer bits = luaL_checkinteger(L, -1);
  if (bits != tm->features)
    luaL_error(L, "input bitmap is the wrong size");
  return raw;
}

lua_Integer _tk_tsetlin_score (tk_tsetlin_t *tm, lua_Integer *bm)
{
	_tk_tsetlin_calculate_clause_output(tm, bm, true);
  return _tk_tsetlin_sum_class_votes(tm);
}

int tk_tsetlin_predict (lua_State *L)
{
  lua_settop(L, 2);
  tk_tsetlin_t *tm = tk_tsetlin_peek(L, 1);
  lua_Integer *bm = tk_tsetlin_peek_raw_bitmap(L, tm, 2);
  lua_Integer score = _tk_tsetlin_score(tm, bm);
  lua_pushboolean(L, score >= 0);
  lua_pushinteger(L, score);
  return 2;
}

int tk_tsetlin_update (lua_State *L)
{
  lua_settop(L, 4);
  tk_tsetlin_t *tm = tk_tsetlin_peek(L, 1);
  lua_Integer *bm = tk_tsetlin_peek_raw_bitmap(L, tm, 2);
  luaL_checktype(L, 3, LUA_TBOOLEAN);
  bool tgt = lua_toboolean(L, 3);
  lua_Number s = luaL_checknumber(L, 4);
  lua_pushvalue(L, 2);
  _tk_tsetlin_update(tm, bm, tgt, s);
  return 0;
}

luaL_Reg tk_tsetlin_fns[] =
{
  { "create", tk_tsetlin_create },
  { "destroy", tk_tsetlin_destroy },
  { "update", tk_tsetlin_update },
  { "predict", tk_tsetlin_predict },
  { NULL, NULL }
};

int luaopen_santoku_tsetlin_bitwise_capi (lua_State *L)
{
  lua_newtable(L); // t
  tk_tsetlin_import(L, "santoku.bitmap", "raw"); // t fn
  tk_tsetlin_register(L, tk_tsetlin_fns, 1); // t
  luaL_newmetatable(L, TK_TSETLIN_MT); // t mt
  lua_pushcfunction(L, tk_tsetlin_destroy); // t mt fn
  lua_setfield(L, -2, "__gc"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
