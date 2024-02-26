local arr = require("santoku.array")
local acat = arr.concat

local bm = require("santoku.bitmap")
local bcreate = bm.create
local bget = bm.get
local bset = bm.set
local bcardinality = bm.cardinality
local bclear = bm.clear
local band = bm["and"]
local bxor = bm.xor
local bor = bm["or"]

local rand = math.random

return function (n_automata, n_bits)

  local sequences = {}
  for i = 1, n_bits do
    sequences[i] = bcreate(n_automata)
  end

  local actions = sequences[1]

  for i = 1, n_automata do
    if rand() > 0.5 then
      bset(actions, i)
    end
  end

  local carry = bcreate()
  local carry_next = bcreate()
  local notter = bcreate()
  bset(notter, 1, n_automata)

  local function increment (incs)
    bclear(carry)
    bor(carry, incs)
    for i = n_bits, 1, -1 do
      if bcardinality(carry) == 0 then
        break
      end
      bclear(carry_next)
      bor(carry_next, sequences[i])
      band(carry_next, carry)
      bxor(sequences[i], carry)
      bclear(carry)
      bor(carry, carry_next)
    end
    if bcardinality(carry) > 0 then
      for i = n_bits, 1, -1 do
        bor(sequences[i], carry)
      end
    end
  end

  local function decrement (decs)
    bclear(carry)
    bor(carry, decs)
    for i = n_bits, 1, -1 do
      if bcardinality(carry) == 0 then
        break
      end
      bclear(carry_next)
      bor(carry_next, sequences[i])
      bxor(carry_next, notter)
      band(carry_next, carry)
      bxor(sequences[i], carry)
      bclear(carry)
      bor(carry, carry_next)
    end
    if bcardinality(carry) > 0 then
      bxor(carry, notter)
      for i = n_bits, 1, -1 do
        band(sequences[i], carry)
      end
    end
  end

  local function calculate_state (n)
    local v = 0
    for i = n_bits, 2, -1 do
      if bget(sequences[i], n) then
        v = v + 2 ^ (n_bits - i)
      end
    end
    if not bget(actions, n) then
      v = -(2 ^ (n_bits - 1)) + v + 1
    end
    return v
  end

  local function tostring (n)
    local out = {}
    for i = 1, n_bits do
      acat[i] = bm.get(sequences[i], n) and 1 or 0
    end
    return acat(out)
  end

  return {
    actions = actions,
    sequences = sequences,
    increment = increment,
    decrement = decrement,
    calculate_state = calculate_state,
    tostring = tostring,
  }

end
