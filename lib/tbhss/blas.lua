local blas = require("tbhss.blas.blas")

local M = {}
local IDX = {}
blas.mt_matrix.__index = IDX

M.matrix = function (t, n, m)

  if getmetatable(t) == blas.mt_matrix then
    if n ~= nil then
      local t0 = blas.matrix(m - n + 1, t:columns())
      t0:copy(t, n, m, 1)
      return t0
    else
      local t0 = blas.matrix(t:rows(), t:columns())
      t0:copy(t, 1, t:rows(), 1)
      return t0
    end
  end

  if type(t) == "number" and type(n) == "number" then
    return blas.matrix(t, n)
  end

  if type(t) ~= "table" then
    error("Unexpected non-table argument to matrix: " .. type(t))
  end

  if #t < 1 then
    error("Can't create a matrix with fewer than 1 rows")
  end

  if type(t[1]) ~= "table" then
    error("Unexpected non-table argument to matrix: " .. type(t[1]))
  end

  if #t[1] < 1 then
    error("Can't create a matrix with fewer than 1 column")
  end

  local m = blas.matrix(#t, #t[1])

  local rows, columns = m:shape()

  for i = 1, rows do
    for j = 1, columns do
      m:set(i, j, t[i][j])
    end
  end

  return m

end

IDX.shape = blas.shape

IDX.rows = function (m)
  return (m:shape())
end

IDX.columns = function (m)
  return (select(2, m:shape()))
end

IDX.amax = blas.amax
IDX.set = blas.set
IDX.get = blas.get
IDX.reshape = blas.reshape
IDX.copy = blas.copy
IDX.sum = blas.sum

IDX.average = function (m, d, row)
  m:sum(d, row)
  d:multiply(row, 1 / m:rows())
  return d
end

IDX.extend = function (m, t, rowstart, rowend)

  if getmetatable(t) == blas.mt_matrix then
    local mrows = m:rows()
    rowstart = rowstart or 1
    rowend = rowend or t:rows()
    blas.reshape(m, m:rows() + rowend - rowstart + 1, m:columns())
    m:copy(t, rowstart, rowend, mrows + 1)
    return m
  end

  if type(t) == "number" then
    blas.reshape(m, m:rows() + t, m:columns())
    return m
  end

  if type(t) ~= "table" then
    error("Unexpected non-table argument to extend: " .. type(t))
  end

  if type(t[1]) == "table" then

    local rows = m:rows()

    blas.reshape(m, m:rows() + #t, m:columns())

    for i = 1, #t do
      for j = 1, m:columns() do
        m:set(rows + i, j, t[i][j])
      end
    end

  else

    blas.reshape(m, m:rows() + 1, m:columns())

    for i = 1, #t do
      m:set(m:rows(), i, t[i])
    end

  end

  return m

end

IDX.normalize = function (m, rowstart, rowend)
  if rowstart == nil and rowend == nil then
    rowstart = 1
    rowend = m:rows()
  elseif rowstart ~= nil and rowend == nil then
    rowend = rowstart
  end
  for i = rowstart, rowend do
    m:multiply(i, 1 / m:magnitude(i))
  end
end

IDX.add = function (a, b, c, d)
  local rowstart = 1
  local rowend = a:rows()
  local add = nil
  if b and c and d then
    rowstart = b
    rowend = c
    add = d
  elseif b and c then
    rowstart = b
    rowend = b
    add = c
  elseif b then
    add = b
  end
  for i = rowstart, rowend do
    blas.radd(a, i, add)
  end
  return a
end

IDX.multiply = function (a, b, c, d)
  if getmetatable(b) == blas.mt_matrix then
    blas.mmult(a, b, c, d and d.transpose_a, d and d.transpose_b)
    return c
  else
    local rowstart = 1
    local rowend = a:rows()
    local mult = nil
    if b and c and d then
      rowstart = b
      rowend = c
      mult = d
    elseif b and c then
      rowstart = b
      rowend = b
      mult = c
    elseif b then
      mult = b
    end
    for i = rowstart, rowend do
      blas.rmult(a, i, mult)
    end
    return a
  end
end

IDX.magnitude = blas.magnitude

blas.mt_matrix.__tostring = function (m)
  local out = { "matrix(", m:rows(), ", ", m:columns(), ") " }
  for i = 1, m:rows() do
    for j = 1, m:columns() do
      out[#out + 1] = string.format("%.2f", m:get(i, j))
      out[#out + 1] = " "
    end
    out[#out + 1] = "// "
  end
  out[#out] = nil
  return table.concat(out)
end

return M
