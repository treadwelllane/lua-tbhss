-- TODO: re-enable when this is re-visited
-- luacheck: ignore

local au = require("santoku.tsetlin.roaring.automata")
local bm = require("santoku.bitmap")
local bcreate = bm.create
local bset = bm.set
local bor = bm["or"]
local band = bm["and"]
local bextend = bm.extend
local bcardinality = bm.cardinality
local bequals = bm.equals
local bclear = bm.clear
local bxor = bm.xor

return function (features, clauses, state_bits, threshold, boost_true_positive)

  local clause_automata = {}
  local clause_outputs = bcreate()
  local clause_tmp = bcreate()

  for c = 1, clauses do
    clause_automata[c] = au(features * 2, state_bits)
  end

  local clause_inputs = bcreate()
  local clause_inputs_not = bcreate()
  local notter = bcreate()
  bset(notter, 1, features)

  local function calculate_outputs (problem, predict)

    -- Copy original features to the clause_inputs bitmap
    bclear(clause_inputs)
    bor(clause_inputs, problem)

    -- Copy inverted features to the clause_inputs_not bitmap
    bclear(clause_inputs_not)
    bor(clause_inputs_not, problem)
    bxor(clause_inputs_not, notter)

    -- Extend the input bitmap so that it includes the original features and the
    -- inverted features and is length 2*features
    bextend(clause_inputs, clause_inputs_not, features)

    -- Count up the yes votes
    for c = 1, clauses do

      local actions = clause_automata[c].actions
      local all_exclude = bcardinality(actions) == 0

      -- AND the inputs with the clause
      bclear(clause_tmp)
      bor(clause_tmp, actions)
      -- TODO: Can this be done lazily such that not all have to be evaluated
      -- unless bequals ends up being true?
      band(clause_tmp, clause_inputs)

      -- If the result equals the actions, set the output
      local output = bequals(actions, clause_tmp) and not (predict and all_exclude)

      if output then
        bset(clause_outputs, c)
      end

    end

  end

  local function sum_votes ()
    -- TODO: Are we missing the polarity concept?
    return bcardinality(clause_outputs)
  end

  local function update (problem, solution, specificity)
    -- TODO
  end

  -- TODO: Extend to support multi-class
  local function predict (problem, solution)
    calculate_outputs(problem, true)
    return sum_votes() > 0
  end

  local function train (problems, solutions, specificity)
    for i = 1, #problems do
      update(problems[i], solutions[i], sensitivity)
    end
  end

  local function evaluate (problems, solutions)
    local correct = 0
    for i = 1, #problems do
      if predict(problems[i]) == solutions[i] then
        correct = correct + 1
      end
    end
    return correct / #problems
  end

  return {
    update = update,
    predict = predict,
    train = train,
    evaluate = evaluate,
  }

end
