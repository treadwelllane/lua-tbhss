local rand = require("santoku.random")
local test = require("santoku.test")
local tm = require("santoku.tsetlin.roaring")
local bm = require("santoku.bitmap")
local fs = require("santoku.fs")
local it = require("santoku.iter")
local str = require("santoku.string")
local arr = require("santoku.array")

rand.seed()

local FEATURES = 12
local CLAUSES = 10
local STATE_BITS = 8
local THRESHOLD = 40
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
    local b = bm.create()
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

test("tsetlin", function ()

  local train_problems, train_solutions =
    read_data("test/res/santoku/tsetlin/NoisyXORTrainingData.txt")

  local test_problems, test_solutions =
    read_data("test/res/santoku/tsetlin/NoisyXORTestData.txt")

  local t = tm(FEATURES, CLAUSES, STATE_BITS, THRESHOLD, BOOST_TRUE_POSITIVE)

  for epoch = 1, MAX_EPOCHS do
    t.train(train_problems, train_solutions, SPECIFICITY)
    local test_score = t.evaluate(test_problems, test_solutions)
    local train_score = t.evaluate(train_problems, train_solutions)
    str.printf("Epoch\t%-4d\tTest\t%4.2f\tTrain\t%4.2f\n", epoch, test_score, train_score)
  end

end)