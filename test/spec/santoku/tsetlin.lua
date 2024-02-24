local rand = require("santoku.random")
local test = require("santoku.test")
local tm_vanilla = require("santoku.tsetlin.vanilla")
local tm_bitwise = require("santoku.tsetlin.bitwise")
local bm = require("santoku.bitmap")
local fs = require("santoku.fs")
local it = require("santoku.iter")
local str = require("santoku.string")
local arr = require("santoku.array")

rand.seed()

local FEATURES = 12
local CLAUSES = 10
local STATES = 128
local STATE_BITS = 8
local THRESHOLD = 20
local SPECIFICITY = 3.9
local BOOST_TRUE_POSITIVE = false
local MAX_EPOCHS = 40

local function read_data (fp, max)
  local problems = {}
  local solutions = {}
  local records = it.map(function (l, s, e)
    return it.map(str.number, str.match(l, "%S+", false, s, e))
  end, fs.lines(fp))
  if max then
    records = it.take(max, records)
  end
  for bits in records do
    local b = bm.create(FEATURES)
    for i = 1, FEATURES do
      if bits() == 1 then
        bm.set(b, i)
      end
    end
    arr.push(problems, b)
    arr.push(solutions, bits() == 1)
  end
  return problems, solutions
end

local train_problems, train_solutions =
  read_data("test/res/santoku/tsetlin/NoisyXORTrainingData.txt")

local test_problems, test_solutions =
  read_data("test/res/santoku/tsetlin/NoisyXORTestData.txt")

local function run (model, ...)

  local t = model.create(...)

  for epoch = 1, MAX_EPOCHS do
    model.train(t, train_problems, train_solutions, SPECIFICITY)
    local score_train = model.evaluate(t, train_problems, train_solutions)
    local score_test = model.evaluate(t, test_problems, test_solutions)
    str.printf("%-4d\t%.2f\t%.2f\n", epoch, score_train, score_test)
  end

end

test("tsetlin", function ()
  run(tm_vanilla, FEATURES, CLAUSES, STATES, THRESHOLD, BOOST_TRUE_POSITIVE)
  run(tm_bitwise, FEATURES, CLAUSES, STATE_BITS, THRESHOLD, BOOST_TRUE_POSITIVE)
end)
