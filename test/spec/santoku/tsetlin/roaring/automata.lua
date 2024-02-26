local test = require("santoku.test")

local err = require("santoku.error")
local assert = err.assert

local validate = require("santoku.validate")
local eq = validate.isequal

local au = require("santoku.tsetlin.roaring.automata")
local bm = require("santoku.bitmap")

test("tsetlin automata", function ()

  local n_automata = 10
  local n_bits = 8
  local automata = au(n_automata, n_bits)

  bm.unset(automata.sequences[1], n_bits)

  local selected = bm.create()
  bm.set(selected, 1)

  automata.increment(selected)
  assert(eq(1, automata.calculate_state(1)))

  automata.increment(selected)
  assert(eq(2, automata.calculate_state(1)))

  automata.decrement(selected)
  assert(eq(1, automata.calculate_state(1)))

  automata.decrement(selected)
  assert(eq(0, automata.calculate_state(1)))

  automata.decrement(selected)
  assert(eq(-0, automata.calculate_state(1)))

  automata.decrement(selected)
  assert(eq(-1, automata.calculate_state(1)))

end)
