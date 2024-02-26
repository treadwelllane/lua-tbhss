#include "lua.h"
#include "lauxlib.h"

#include "roaring.c"
#include <stdbool.h>
#include <stdlib.h>

#define TK_TSETLIN_MT "santoku_tsetlin"

typedef struct {

  lua_Integer features;
  lua_Integer clauses;
  lua_Integer states;
  lua_Number threshold;
  bool boost_true_positive;

  lua_Integer *automata_states;
  lua_Integer *clause_outputs;
  lua_Integer *clause_feedback;

} tk_tsetlin_t;

#define tk_tsetlin_automata_idx(t, f, l, p) (f + (l * (t)->features * 2) + (p ? (t)->features : 0))
#define tk_tsetlin_clause_idx(t, l) (l)
#define tk_tsetlin_action(t, n) (n > (t)->states)

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

// TODO: Duplicated across various libraries, need to consolidate
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

tk_tsetlin_t **tk_tsetlin_peekp (lua_State *L, int i)
{
  return (tk_tsetlin_t **) luaL_checkudata(L, i, TK_TSETLIN_MT);
}

tk_tsetlin_t *tk_tsetlin_peek (lua_State *L, int i)
{
  return *tk_tsetlin_peekp(L, i);
}

roaring_bitmap_t *tk_tsetlin_peek_raw_bitmap (lua_State *L, tk_tsetlin_t *tm, int i)
{
  return *((roaring_bitmap_t **) luaL_checkudata(L, i, "santoku_bitmap"));
}

int tk_tsetlin_destroy (lua_State *L)
{
  lua_settop(L, 1);
  tk_tsetlin_t **tm0p = tk_tsetlin_peekp(L, 1);
  tk_tsetlin_t *tm0 = *tm0p;
  if (tm0 == NULL)
    return 0;
  free(tm0->automata_states);
  free(tm0->clause_outputs);
  free(tm0->clause_feedback);
  tm0->automata_states = NULL;
  tm0->clause_outputs = NULL;
  tm0->clause_feedback = NULL;
  free(tm0);
  *tm0p = NULL;
  return 0;
}

int tk_tsetlin_create (lua_State *L)
{
  tk_tsetlin_t *tm0 = (tk_tsetlin_t *) malloc(sizeof(tk_tsetlin_t));
  if (!tm0)
    goto err_mem;

  lua_settop(L, 5);

  tm0->features = luaL_checkinteger(L, 1);
  tm0->clauses = luaL_checkinteger(L, 2);
  tm0->states = luaL_checkinteger(L, 3);
  tm0->threshold = luaL_checknumber(L, 4);

  luaL_checktype(L, 5, LUA_TBOOLEAN);
  tm0->boost_true_positive = lua_toboolean(L, 5);

  tm0->automata_states = malloc(sizeof(lua_Integer) * tm0->features * tm0->clauses * 2);
  tm0->clause_outputs = malloc(sizeof(lua_Integer) * tm0->clauses);
  tm0->clause_feedback = malloc(sizeof(lua_Integer) * tm0->clauses);

  if (!(tm0->automata_states || tm0->clause_outputs || tm0->clause_feedback))
    goto err_mem;

  for (lua_Integer f = 0; f < tm0->features; f ++) {
    for (lua_Integer l = 0; l < tm0->clauses; l ++) {
      if (1.0 * rand() / RAND_MAX <= 0.5) {
        tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, l, 0)] = tm0->states;
        tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, l, 1)] = tm0->states + 1;
      } else {
        tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, l, 0)] = tm0->states + 1;
        tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, l, 1)] = tm0->states;
      }
    }
  }

  tk_tsetlin_t **tm0p = (tk_tsetlin_t **) lua_newuserdata(L, sizeof(tk_tsetlin_t *));
  *tm0p = tm0;

  luaL_getmetatable(L, TK_TSETLIN_MT);
  lua_setmetatable(L, -2);

  return 1;

err_mem:
  luaL_error(L, "Error in malloc during tsetlin create");
  return 0;
}

void _tk_tsetlin_calculate_clause_output (lua_State *L, tk_tsetlin_t *tm0, roaring_bitmap_t *bm, bool predict)
{
	lua_Integer action_include, action_include_negated;
	lua_Integer all_exclude;
	for (lua_Integer l = 0; l < tm0->clauses; l ++) {
    lua_Integer clause_idx = tk_tsetlin_clause_idx(tm0, l);
    tm0->clause_outputs[clause_idx] = 1;
		all_exclude = 1;
		for (lua_Integer f = 0; f < tm0->features; f ++) {
			action_include = tk_tsetlin_action(tm0, tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, l, 0)]);
			action_include_negated = tk_tsetlin_action(tm0, tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, l, 1)]);
			all_exclude = all_exclude && !(action_include == 1 || action_include_negated == 1);
      bool is_set = roaring_bitmap_contains(bm, f);
			if ((action_include == 1 && !is_set) || (action_include_negated == 1 && is_set)) {
        tm0->clause_outputs[clause_idx] = 0;
				break;
			}
		}
    tm0->clause_outputs[clause_idx] = tm0->clause_outputs[clause_idx] && !(predict && all_exclude == 1);
	}
}

lua_Integer _tk_tsetlin_sum_class_votes (lua_State *L, tk_tsetlin_t *tm0)
{
  lua_Integer class_sum = 0;
  for (lua_Integer l = 0; l < tm0->clauses; l ++) {
    int sign = 1 - 2 * (l & 1);
    class_sum += tm0->clause_outputs[tk_tsetlin_clause_idx(tm0, l)] * sign;
  }
  class_sum = (class_sum > tm0->threshold) ? tm0->threshold : class_sum;
  class_sum = (class_sum < -tm0->threshold) ? -tm0->threshold : class_sum;
  return class_sum;
}

void _tk_tsetlin_type_ii_feedback (lua_State *L, tk_tsetlin_t *tm0, roaring_bitmap_t *bm, lua_Integer l)
{
	lua_Integer action_include;
	lua_Integer action_include_negated;
  if (tm0->clause_outputs[tk_tsetlin_clause_idx(tm0, l)]) {
		for (lua_Integer f = 0; f < tm0->features; f ++) {
      lua_Integer idx0 = tk_tsetlin_automata_idx(tm0, f, l, 0);
      lua_Integer idx1 = tk_tsetlin_automata_idx(tm0, f, l, 1);
			action_include = tk_tsetlin_action(tm0, tm0->automata_states[idx0]);
			action_include_negated = tk_tsetlin_action(tm0, tm0->automata_states[idx1]);
      bool is_set = roaring_bitmap_contains(bm, f);
      tm0->automata_states[idx0] += (action_include == 0 && tm0->automata_states[idx0] < tm0->states * 2) && !is_set;
      tm0->automata_states[idx1] += (action_include_negated == 0 && tm0->automata_states[idx1] < tm0->states * 2) && is_set;
    }
	}
}

void _tk_tsetlin_type_i_feedback (lua_State *L, tk_tsetlin_t *tm0, roaring_bitmap_t *bm, lua_Integer l, lua_Number s)
{
  lua_Integer clause_idx = tk_tsetlin_clause_idx(tm0, l);
	if (tm0->clause_outputs[clause_idx] == 0)	{
		for (int f = 0; f < tm0->features; f ++) {
      lua_Integer idx0 = tk_tsetlin_automata_idx(tm0, f, l, 0);
      lua_Integer idx1 = tk_tsetlin_automata_idx(tm0, f, l, 1);
      tm0->automata_states[idx0] -= (tm0->automata_states[idx0] > 1) && (1.0 * rand() / RAND_MAX <= 1.0 / s);
      tm0->automata_states[idx1] -= (tm0->automata_states[idx1] > 1) && (1.0 * rand() / RAND_MAX <= 1.0 / s);
		}
	} else if (tm0->clause_outputs[clause_idx] == 1) {
		for (int f = 0; f < tm0->features; f ++) {
      bool is_set = roaring_bitmap_contains(bm, f);
      lua_Integer idx0 = tk_tsetlin_automata_idx(tm0, f, l, 0);
      lua_Integer idx1 = tk_tsetlin_automata_idx(tm0, f, l, 1);
			if (is_set) {
				tm0->automata_states[idx0] += (tm0->automata_states[idx0] < tm0->states * 2)
          && (tm0->boost_true_positive == 1 || 1.0 * rand() / RAND_MAX <= (s - 1) / s);
				tm0->automata_states[idx1] -= (tm0->automata_states[idx1] > 1)
          && (1.0 * rand() / RAND_MAX <= 1.0 / s);
			} else if (!is_set) {
				tm0->automata_states[idx1] += (tm0->automata_states[idx1] < tm0->states * 2)
          && (tm0->boost_true_positive == 1 || 1.0 * rand() / RAND_MAX <= (s - 1) / s);
				tm0->automata_states[idx0] -= (tm0->automata_states[idx0] > 1)
          && (1.0 * rand() / RAND_MAX <= 1.0 / s);
			}
		}
	}
}

void _tk_tsetlin_update (lua_State *L, tk_tsetlin_t *tm0, roaring_bitmap_t *bm, bool tgt, lua_Number s)
{
	_tk_tsetlin_calculate_clause_output(L, tm0, bm, false);
	lua_Integer class_sum = _tk_tsetlin_sum_class_votes(L, tm0);
  tgt = tgt ? 1 : 0;
	for (lua_Integer l = 0; l < tm0->clauses; l ++) {
    tm0->clause_feedback[tk_tsetlin_clause_idx(tm0, l)] =
		  (2 * tgt - 1) *
      (1 - 2 * (l & 1)) *
      (1.0 * rand() / RAND_MAX <=
        (1.0 / (tm0->threshold * 2)) *
        (tm0->threshold + (1 - 2 * tgt) * class_sum));
  }
	for (int l = 0; l < tm0->clauses; l ++) {
    lua_Integer fb = tm0->clause_feedback[tk_tsetlin_clause_idx(tm0, l)];
		if (fb > 0) {
			_tk_tsetlin_type_i_feedback(L, tm0, bm, l, s);
    } else if (fb < 0) {
			_tk_tsetlin_type_ii_feedback(L, tm0, bm, l);
    }
	}
}

lua_Integer _tk_tsetlin_score (lua_State *L, tk_tsetlin_t *tm0, roaring_bitmap_t *bm)
{
	_tk_tsetlin_calculate_clause_output(L, tm0, bm, true);
  return _tk_tsetlin_sum_class_votes(L, tm0);
}

int tk_tsetlin_predict (lua_State *L)
{
  lua_settop(L, 2);
  tk_tsetlin_t *tm0 = tk_tsetlin_peek(L, 1);
  roaring_bitmap_t *bm = tk_tsetlin_peek_raw_bitmap(L, tm0, 2);
  lua_Integer score = _tk_tsetlin_score(L, tm0, bm);
  lua_pushboolean(L, score >= 0);
  lua_pushinteger(L, score);
  return 2;
}

int tk_tsetlin_update (lua_State *L)
{
  lua_settop(L, 4);
  tk_tsetlin_t *tm0 = tk_tsetlin_peek(L, 1);
  roaring_bitmap_t *bm = tk_tsetlin_peek_raw_bitmap(L, tm0, 2);
  luaL_checktype(L, 3, LUA_TBOOLEAN);
  bool tgt = lua_toboolean(L, 3);
  lua_Number s = luaL_checknumber(L, 4);
  lua_pushvalue(L, 2);
  _tk_tsetlin_update(L, tm0, bm, tgt, s);
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

int luaopen_santoku_tsetlin_vanilla_capi (lua_State *L)
{
  lua_newtable(L); // t
  tk_tsetlin_register(L, tk_tsetlin_fns, 0); // t
  luaL_newmetatable(L, TK_TSETLIN_MT); // t mt
  lua_pushcfunction(L, tk_tsetlin_destroy); // t mt fn
  lua_setfield(L, -2, "__gc"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
