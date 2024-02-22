local mtx = require("santoku.matrix")

local m0 = mtx.matrix(1, 10)

for i = 1, 5 do
  mtx.set(m0, 1, i, i)
end

for i = 1, 5 do
  assert(mtx.get(m0, 1, i), i)
end

mtx.add(m0, -1)

for i = 1, 5 do
  assert(mtx.get(m0, 1, i), i - 1)
end
