local test = require("santoku.test")

local err = require("santoku.error")
local assert = err.assert

local validate = require("santoku.validate")
local eq = validate.isequal

local au = require("santoku.tsetlin.automata")
local bm = require("santoku.bitmap")

test("integer", function ()
  local b
  b = bm.create(8)
  assert(eq(bm.integer(b), 0))
  bm.set(b, 1)
  assert(eq(bm.integer(b), 128))
  b = bm.create(8, 1)
  assert(eq(bm.integer(b), 255))
  b = bm.create(8)
  bm.set(b, 1)
  assert(eq(bm.integer(b), 128))
  bm.set(b, 2)
  bm.unset(b, 1)
  assert(eq(bm.integer(b), 64))
  bm.set(b, 1)
  assert(eq(bm.integer(b), 192))
  bm.set(b, 4)
  assert(eq(bm.integer(b), 208))
end)

test("tsetlin-bitmap", function ()

  local num_automata = 64
  local state_index_bits = 8 -- 2^7, where bit #8 represents automata output

  -- initialize tsetlin automata states
  local automata = au(num_automata, state_index_bits)

  -- show automata #1 decision
  print("> action", bm.get(automata.actions, 1))

  -- show corresponding state value [ -2^7, +2^7 ]
  print("> state", automata.calculate_state(1))

  -- show all actions
  print("> all", automata.actions)

  -- bitmap with increments
  local incs = bm.create(bm.size(automata.actions), 0)
  bm.set(incs, 1) -- increment automata 1

  -- bitmap of decrements, no decrements
  local decs = bm.create(bm.size(automata.actions), 1)

  print("> updating")
  automata.increment(incs)
  automata.decrement(decs)

  -- show automata #1 decision
  print("> action", bm.get(automata.actions, 1))

  -- show corresponding state value [ -2^7, +2^7 ]
  print("> state", automata.calculate_state(1))

  -- show all actions
  print("> all", automata.actions)

end)
