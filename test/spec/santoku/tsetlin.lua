local rand = require("santoku.random")
local test = require("santoku.test")
local tm = require("santoku.tsetlin")
local bm = require("santoku.bitmap")
local fs = require("santoku.fs")
local it = require("santoku.iter")
local str = require("santoku.string")
local arr = require("santoku.array")

rand.seed()

local FEATURES = 12
local CLASSES = 1
local CLAUSES = 10
local STATES = 100
local THRESHOLD = 15
local SPECIFICITY = 3.9
local BOOST_TRUE_POSITIVE = false

local MAX_EPOCHS = 100
local MAX_SCORE = 1

local function read_data (fp)
  local problems = {}
  local solutions = {}
  for bits in it.map(function (l, s, e)
    return it.map(str.number, str.match(l, "%S+", false, s, e))
  end, fs.lines(fp)) do
    local b = bm.create(FEATURES)
    for i = 1, FEATURES do
      if bits() == 1 then
        bm.set(b, i)
      end
    end
    arr.push(problems, b)
    local s = bm.create(CLASSES)
    bm.set(s, bits())
    arr.push(solutions, s)
  end
  return problems, solutions
end

test("tsetlin", function ()

  local train_problems, train_solutions =
    read_data("test/res/santoku/tsetlin/NoisyXORTrainingData.txt")

  local test_problems, test_solutions =
    read_data("test/res/santoku/tsetlin/NoisyXORTestData.txt")

  local t = tm.create(FEATURES, CLASSES, CLAUSES, STATES, THRESHOLD, BOOST_TRUE_POSITIVE)

  for epoch = 1, MAX_EPOCHS do
    tm.train(t, train_problems, train_solutions, SPECIFICITY)
    local score = tm.evaluate(t, test_problems, test_solutions)
    str.printf("Epoch %d:  %.2f", i, score)
    if score >= MAX_SCORE then
      break
    end
  end

end)
