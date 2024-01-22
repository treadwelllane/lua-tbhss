local blas = require("tbhss.blas")

local m0 = blas.matrix({ { 1, 2, 3 }, { 4, 5, 6 } })

print(m0)
m0:add(2)
print(m0)

-- print(m0)
-- m0:normalize()
-- print(m0)
-- m0:normalize()
-- print(m0)
-- m0:normalize()
-- print(m0)

-- m0:average(m1, 1)

-- print(m1)

-- m:normalize()

-- print(m)
-- print(m:shape())
