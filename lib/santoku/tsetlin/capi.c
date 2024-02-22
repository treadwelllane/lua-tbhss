#include "lua.h"
#include "lauxlib.h"

#include <stdbool.h>
#include <stdlib.h>

#define TK_TSETLIN_MT "santoku_tsetlin"

typedef struct {

  lua_Integer features;
  lua_Integer classes;
  lua_Integer clauses;
  lua_Integer states;
  lua_Number threshold;
  bool boost_true_positive;

  lua_Integer *automata_states; // [features][classes][clauses][polarity]
  lua_Integer *clause_outputs; // [classes][clauses]
  lua_Integer *clause_feedback; // [classes][clauses]

} tk_tsetlin_t;

// TODO: Refine this ordering to maximize data locality at runtime
#define tk_tsetlin_automata_idx(t, f, c, l, p) \
  (f + (c * (t)->features) \
     + (l * (t)->features * (t)->classes) \
     + (p * (t)->features * (t)->classes * (t)->clauses))
#define tk_tsetlin_clause_idx(t, c, l) \
  (c + (l * (t)->clauses))

#define tk_tsetlin_action(t, n) (n > (t)->states)

tk_tsetlin_t *tk_tsetlin_peek (lua_State *L, int i)
{
  return *((tk_tsetlin_t **) luaL_checkudata(L, i, TK_TSETLIN_MT));
}

int tk_tsetlin_destroy (lua_State *L)
{
  lua_settop(L, 1);
  tk_tsetlin_t *tm0 = tk_tsetlin_peek(L, 1);
  free(tm0);
  return 1;
}

int tk_tsetlin_create (lua_State *L)
{
  tk_tsetlin_t *tm0 = (tk_tsetlin_t *) malloc(sizeof(tk_tsetlin_t));
  if (!tm0)
    goto err_mem;

  lua_settop(L, 6);

  tm0->features = luaL_checkinteger(L, 1);
  tm0->classes = luaL_checkinteger(L, 2);
  tm0->clauses = luaL_checkinteger(L, 3);
  tm0->states = luaL_checkinteger(L, 4);
  tm0->threshold = luaL_checknumber(L, 5);

  luaL_checktype(L, 6, LUA_TBOOLEAN);
  tm0->boost_true_positive = lua_toboolean(L, 6);

  tm0->automata_states = malloc(sizeof(*tm0->automata_states) * tm0->features * tm0->classes * tm0->clauses * 2);
  tm0->clause_outputs = malloc(sizeof(*tm0->clause_outputs) * tm0->classes * tm0->clauses);
  tm0->clause_feedback = malloc(sizeof(*tm0->clause_outputs) * tm0->classes * tm0->clauses);

  if (!(tm0->automata_states || tm0->clause_outputs || tm0->clause_feedback))
    goto err_mem;

  // TODO: Configurable random memory range.
  // Instead of setting states to either tm0->states and tm0->states + 1 we can
  // randomly select between
  //   [0, tm0->states] and
  //   [tm0->states, tm0->states * 2]
  for (lua_Integer f = 0; f < tm0->features; f ++) {
    for (lua_Integer c = 0; c < tm0->classes; c ++) {
      for (lua_Integer l = 0; l < tm0->clauses; l ++) {
        if (1.0 * rand() / RAND_MAX <= 0.5) {
          tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, c, l, 0)] = tm0->states;
          tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, c, l, 1)] = tm0->states + 1;
        } else {
          tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, c, l, 0)] = tm0->states + 1;
          tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, c, l, 1)] = tm0->states;
        }
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

void _tk_tsetlin_calculate_clause_output (lua_State *L, tk_tsetlin_t *tm0, lua_Integer c, bool predict)
{
	lua_Integer action_include, action_include_negated;
	lua_Integer all_exclude;
	for (lua_Integer l = 0; l < tm0->clauses; l ++) {
    lua_Integer clause_idx = tk_tsetlin_clause_idx(tm0, c, l);
    tm0->clause_outputs[clause_idx] = 1;
		all_exclude = 1;
		for (lua_Integer f = 0; f < tm0->features; f ++) {
			action_include = tk_tsetlin_action(tm0, tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, c, l, 0)]);
			action_include_negated = tk_tsetlin_action(tm0, tm0->automata_states[tk_tsetlin_automata_idx(tm0, f, c, l, 1)]);
			all_exclude = all_exclude && !(action_include == 1 || action_include_negated == 1);
      lua_pushvalue(L, -2); // problem solution problem
      lua_pushinteger(L, f + 1); // problem solution problem idx
      tk_tsetlin_callmod(L, 2, 1, "santoku.bitmap", "get");
      bool is_set = lua_toboolean(L, -1);
      lua_pop(L, 1); // problem solution
			if ((action_include == 1 && !is_set) || (action_include_negated == 1 && is_set)) {
        tm0->clause_outputs[clause_idx] = 0;
				break;
			}
		}
    tm0->clause_outputs[clause_idx] = tm0->clause_outputs[clause_idx] && !(predict && all_exclude == 1);
	}
}

lua_Integer _tk_tsetlin_sum_class_votes (lua_State *L, tk_tsetlin_t *tm0, lua_Integer c)
{
  lua_Integer class_sum = 0;
  for (lua_Integer l = 0; l < tm0->clauses; l ++) {
    int sign = 1 - 2 * (l & 1);
    class_sum += tm0->clause_outputs[tk_tsetlin_clause_idx(tm0, c, l)] * sign;
  }
  class_sum = (class_sum > tm0->threshold) ? tm0->threshold : class_sum;
  class_sum = (class_sum < -tm0->threshold) ? -tm0->threshold : class_sum;
  return class_sum;
}

void _tk_tsetlin_type_ii_feedback (lua_State *L, tk_tsetlin_t *tm0, lua_Integer c, lua_Integer l)
{
	lua_Integer action_include;
	lua_Integer action_include_negated;
  if (tm0->clause_outputs[tk_tsetlin_clause_idx(tm0, c, l)]) {
		for (lua_Integer f = 0; f < tm0->features; f ++) {
      lua_Integer idx0 = tk_tsetlin_automata_idx(tm0, f, c, l, 0);
      lua_Integer idx1 = tk_tsetlin_automata_idx(tm0, f, c, l, 1);
			action_include = tk_tsetlin_action(tm0, tm0->automata_states[idx0]);
			action_include_negated = tk_tsetlin_action(tm0, tm0->automata_states[idx1]);
      tm0->automata_states[idx0] += (action_include == 0 && tm0->automata_states[idx0] < tm0->states * 2);
      tm0->automata_states[idx1] += (action_include_negated == 0 && tm0->automata_states[idx1] < tm0->states * 2);
		}
	}
}

void _tk_tsetlin_type_i_feedback (lua_State *L, tk_tsetlin_t *tm0, lua_Integer c, lua_Integer l, lua_Number s)
{
  lua_Integer clause_idx = tk_tsetlin_clause_idx(tm0, c, l);
	if (tm0->clause_outputs[clause_idx] == 0)	{
		for (int f = 0; f < tm0->features; f ++) {
      lua_Integer idx0 = tk_tsetlin_automata_idx(tm0, c, l, f, 0);
      lua_Integer idx1 = tk_tsetlin_automata_idx(tm0, c, l, f, 1);
      tm0->automata_states[idx0] -= tm0->automata_states[idx0] && (1.0 * rand() / RAND_MAX <= 1.0 / s);
      tm0->automata_states[idx1] -= tm0->automata_states[idx1] && (1.0 * rand() / RAND_MAX <= 1.0 / s);
		}
	} else if (tm0->clause_outputs[clause_idx] == 1) {
		for (int f = 0; f < tm0->features; f ++) {
      lua_pushvalue(L, -2); // problem solution problem
      lua_pushinteger(L, f + 1); // problem solution problem idx
      tk_tsetlin_callmod(L, 2, 1, "santoku.bitmap", "get");
      bool is_set = lua_toboolean(L, -1);
      lua_pop(L, 1); // problem solution
      lua_Integer idx0 = tk_tsetlin_automata_idx(tm0, c, l, f, 0);
      lua_Integer idx1 = tk_tsetlin_automata_idx(tm0, c, l, f, 1);
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

void _tk_tsetlin_update_class (lua_State *L, tk_tsetlin_t *tm0, lua_Integer c, lua_Integer tgt, lua_Number s)
{
	_tk_tsetlin_calculate_clause_output(L, tm0, c, false); // problem solution
	lua_Integer class_sum = _tk_tsetlin_sum_class_votes(L, tm0, c); // problem solution
	for (lua_Integer l = 0; l < tm0->clauses; l ++) {
    tm0->clause_feedback[tk_tsetlin_clause_idx(tm0, c, l)] =
		  (2 * tgt - 1) *
      (1 - 2 * (l & 1)) *
      (1.0 * rand() / RAND_MAX <=
        (1.0 / (tm0->threshold * 2)) *
        (tm0->threshold + (1 - 2 * tgt) * class_sum));
  }
	for (int l = 0; l < tm0->clauses; l ++) {
    lua_Integer fb = tm0->clause_feedback[tk_tsetlin_clause_idx(tm0, c, l)];
		if (fb > 0)
			_tk_tsetlin_type_i_feedback(L, tm0, c, l, s); // problem solution
		else if (fb < 0)
			_tk_tsetlin_type_ii_feedback(L, tm0, c, l); // problem solution
	}
}

void _tk_tsetlin_update (lua_State *L, tk_tsetlin_t *tm0, lua_Number s)
{
  for (lua_Integer c = 0; c < tm0->classes; c ++) {
    _tk_tsetlin_update_class(L, tm0, c, 1, s); // problem solution
    lua_Integer c0;
    for (c0 = c; c0 == c; c0 = tm0->classes * 1.0 * rand() / RAND_MAX + 1);
    _tk_tsetlin_update_class(L, tm0, c0, 0, s); // problem solution
  }
}

int tk_tsetlin_train (lua_State *L)
{
  lua_settop(L, 4);
  tk_tsetlin_t *tm0 = tk_tsetlin_peek(L, 1);
  luaL_checktype(L, 2, LUA_TTABLE);
  luaL_checktype(L, 3, LUA_TTABLE);
  lua_Number s = luaL_checknumber(L, 4);
  lua_Integer nprob = lua_objlen(L, 2);
  for (lua_Integer i = 1; i <= nprob; i++) {
    lua_pushinteger(L, i);
    lua_gettable(L, 2); // problem
    lua_pushinteger(L, i);
    lua_gettable(L, 3); // problem solution
    _tk_tsetlin_update(L, tm0, s);
    lua_pop(L, 2);
  }
  return 0;
}

luaL_Reg tk_tsetlin_fns[] =
{
  { "create", tk_tsetlin_create },
  { "destroy", tk_tsetlin_destroy },
  { "train", tk_tsetlin_train },
  { NULL, NULL }
};

int luaopen_santoku_tsetlin_capi (lua_State *L)
{
  lua_newtable(L); // t
  luaL_register(L, NULL, tk_tsetlin_fns); // t
  luaL_newmetatable(L, TK_TSETLIN_MT); // t mt
  lua_pushcfunction(L, tk_tsetlin_destroy); // t mt fn
  lua_setfield(L, -2, "__gc"); // t mt
  lua_pop(L, 1); // t
  return 1;
}
