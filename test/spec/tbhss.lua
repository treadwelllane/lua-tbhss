local test = require("santoku.test")
local gen = require("santoku.gen")
local str = require("santoku.string")
local vec = require("santoku.vector")
local err = require("santoku.err")
local fs = require("santoku.fs")
local fun = require("santoku.fun")
local op = require("santoku.op")

local tbhss = require("tbhss")

test("tbhss", function ()

  local iterations = 25
  local model = tbhss.create({
    embedding_size = 4096 -- bits,
  })

  local ds = vec()
  local as = vec()
  local bs = vec()

  err.check(fs.lines("test/res/stsbenchmark/sts-dev.csv"))
    :map(fun.bindr(str.split, "\t"))
    :map(vec.unpack)
    :map(fun.nret(5, 6, 7))
    :filter(fun.compose(op["not"], str.isempty, fun.nret(1)))
    :each(function (d, a, b)
      ds:append(1 - d / 5)
      as:append(a)
      bs:append(b)
    end)

  for n = 1, iterations do
    str.printf("Iteration: %d\t", n)
    local loss = gen.nkeys(ds):map(function (i)
      local d = model:distance(model:encode(as[i]), model:encode(bs[i]))
      return (ds[i] - d) ^ 2
    end):sum() / ds.n
    str.printf("Loss: %f\n", loss)
    model:train(loss)
  end

  gen.nkeys(ds):each(function (i)
    print(i, 5 * (1 - model:distance(model:encode(as[i]), model:encode(bs[i]))))
  end)

end)
