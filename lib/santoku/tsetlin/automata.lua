local arr = require("santoku.array")
local apush = arr.push

local bm = require("santoku.bitmap")
local bcreate = bm.create
local bget = bm.get
local bset = bm.set
local binteger = bm.integer
local brandomize = bm.randomize

return function (n_automata, n_bits)

  local sequences = {}
  for i = 1, n_bits do
    apush(sequences, bcreate(n_automata, i == n_bits))
  end

  local actions = sequences[1]
  brandomize(actions)

  local function increment (incs)
    -- TODO
  end

  local function decrement (decs)
    -- TODO
  end

  local function calculate_state (n)
    local m = bcreate(n_bits)
    for i = 2, n_bits do
      if bget(sequences[i], n) then
        bset(m, i)
      end
    end
    local v = binteger(m)
    if not bget(actions, n) then
      v = -v
    end
    return v
  end

  return {
    actions = actions,
    sequences = sequences,
    increment = increment,
    decrement = decrement,
    calculate_state = calculate_state
  }

end


-- #include "lua.h"
-- #include "lauxlib.h"

-- #include <stdbool.h>
-- #include <stdlib.h>

-- #define TK_TSETLIN_AUTOMATA_MT "santoku_tsetlin"

-- enum TK_TSETLIN_AUTOMATA_UPVALUE {
--   TK_TSETLIN_AUTOMATA_UPVALUE_BCREATE = 1;
--   TK_TSETLIN_AUTOMATA_UPVALUE_BRANDOMIZE;
-- };

-- typedef struct {
--   lua_Integer sequences;
--   lua_Integer *ref_sequences;
-- } tk_tsetlin_automata_t;

-- // TODO: Duplicated across various libraries, need to consolidate
-- void tk_lua_import (lua_State *L, const char *smod, const char *sfn)
-- {
--   lua_getglobal(L, "require"); // req
--   lua_pushstring(L, smod); // req smod
--   lua_call(L, 1, 1); // mod
--   lua_pushstring(L, sfn); // mod sfn
--   lua_gettable(L, -2); // mod fn
--   lua_remove(L, -2); // fn
-- }

-- // TODO: Duplicated across various libraries, need to consolidate
-- void tk_lua_callmod (lua_State *L, int nargs, int nret, const char *smod, const char *sfn)
-- {
--   lua_getglobal(L, "require"); // arg req
--   lua_pushstring(L, smod); // arg req smod
--   lua_call(L, 1, 1); // arg mod
--   lua_pushstring(L, sfn); // args mod sfn
--   lua_gettable(L, -2); // args mod fn
--   lua_remove(L, -2); // args fn
--   lua_insert(L, - nargs - 1); // fn args
--   lua_call(L, nargs, nret); // results
-- }

-- // TODO: Duplicated across various libraries, need to consolidate
-- void tk_lua_callupvalue (lua_State *L, int nargs, int nret, int idx)
-- {
--   lua_pushvalue(L, lua_upvalueindex(idx)); // args fn
--   lua_insert(L, - nargs - 1); // fn args
--   lua_call(L, nargs, nret); // results
-- }

-- void tk_lua_deref (lua_State *L, int ref)
-- {
--   lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
-- }

-- void tk_lua_register (lua_State *L, luaL_Reg *regs, int nup)
-- {
--   while (true) {
--     if ((*regs).name == NULL)
--       break;
--     for (int i = 0; i < nup; i ++)
--       lua_pushvalue(L, -nup); // t upsa upsb
--     lua_pushcclosure(L, (*regs).func, nup); // t upsa fn
--     lua_setfield(L, -nup - 2, (*regs).name); // t
--     regs ++;
--   }
--   lua_pop(L, nup);
-- }

-- tk_tsetlin_automata_t **tk_tsetlin_automata_peekp (lua_State *L, int i)
-- {
--   return (tk_tsetlin_automata_t **) luaL_checkudata(L, i, TK_TSETLIN_AUTOMATA_MT);
-- }

-- tk_tsetlin_automata_t *tk_tsetlin_automata_peek (lua_State *L, int i)
-- {
--   return *tk_tsetlin_automata_peekp(L, i);
-- }

-- int tk_tsetlin_automata_destroy (lua_State *L)
-- {
--   lua_settop(L, 1);
--   tk_tsetlin_automata_t **tm0p = tk_tsetlin_automata_peekp(L, 1);
--   tk_tsetlin_automata_t *tm0 = *tm0p;
--   if (tm0 == NULL)
--     return 0;
--   for (lua_Integer i = 0; i < tm0->sequences; i ++)
--     luaL_unref(L, tm0->ref_sequences[i]);
--   free(tm0->ref_sequences);
--   free(tm0);
--   *tm0p = NULL;
--   return 0;
-- }

-- int tk_tsetlin_automata_create (lua_State *L)
-- {
--   tk_tsetlin_automata_t *tm0 = malloc(sizeof(tk_tsetlin_automata_t));
--   if (!tm0)
--     goto err_mem;

--   lua_settop(L, 2);
--   tm0->sequences = luaL_checkinteger(L, 1);
--   tm0->automata = luaL_checkinteger(L, 2);
--   tm0->ref_sequences = malloc(sizeof(lua_Integer) * tm0->sequences);
--   if (!tm0->ref_sequences)
--     goto err_mem;

--   for (lua_Integer i = 0; i < tm0->sequences; i ++) {
--     lua_pushinteger(L, tm0->automata);
--     tk_lua_callupvalue(L, 1, 1, TK_TSETLIN_AUTOMATA_UPVALUE_BCREATE);
--     tm0->ref_sequences[i] = luaL_ref(L);
--   }

--   tk_lua_deref(L, tm0->ref_sequences[i])
--   tk_lua_callupvalue(L, 1, 1, TK_TSETLIN_AUTOMATA_UPVALUE_BRANDOMIZE);

--   tk_tsetlin_automata_t **tm0p = (tk_tsetlin_automata_t **) lua_newuserdata(L, sizeof(tk_tsetlin_automata_t *));
--   *tm0p = tm0;

--   luaL_getmetatable(L, TK_TSETLIN_AUTOMATA_MT);
--   lua_setmetatable(L, -2);

--   return 1;

-- err_mem:
--   luaL_error(L, "Error in malloc during tsetlin automata create");
--   return 0;
-- }

-- int tk_tsetlin_update (lua_State *L)
-- {
--   lua_settop(L, 4);
--   tk_tsetlin_t *tm0 = tk_tsetlin_peek(L, 1);
--   luaL_checkudata(L, 2, "santoku_bitmap");
--   luaL_checktype(L, 3, LUA_TBOOLEAN);
--   bool tgt = lua_toboolean(L, 3);
--   lua_Number s = luaL_checknumber(L, 4);
--   lua_pushvalue(L, 2);
--   _tk_tsetlin_update(L, tm0, tgt, s);
--   return 0;
-- }

-- luaL_Reg tk_tsetlin_automata_fns[] =
-- {
--   { "create", tk_tsetlin_automata_create },
--   { "destroy", tk_tsetlin_automata_destroy },
--   { "actions", tk_tsetlin_automata_actions },
--   { "calculate_state", tk_tsetlin_automata_calculate_state },
--   { NULL, NULL }
-- };

-- int luaopen_santoku_tsetlin_automata_capi (lua_State *L)
-- {
--   lua_newtable(L); // t
--   tk_lua_import(L, "santoku.bitmap", "create"); // t fn
--   tk_lua_import(L, "santoku.bitmap", "randomize"); // t fn
--   tk_lua_register(L, tk_tsetlin_automata_fns, 2); // t
--   luaL_newmetatable(L, TK_TSETLIN_AUTOMATA_MT); // t mt
--   lua_pushcfunction(L, tk_tsetlin_automata_destroy); // t mt fn
--   lua_setfield(L, -2, "__gc"); // t mt
--   lua_pop(L, 1); // t
--   return 1;
-- }

