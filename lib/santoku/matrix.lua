local mtx = require("santoku.matrix.capi")
local mt_matrix = mtx.mt_matrix
local bmatrix = mtx.matrix
local bset = mtx.set
local bsums = mtx.sums
local bcopy = mtx.copy
local breshape = mtx.reshape
local bextend_raw = mtx.extend_raw
local brows = mtx.rows
local bcolumns = mtx.columns
local bmagnitude = mtx.magnitude
local bradd = mtx.radd
local bexp = mtx.exp
local bsum = mtx.sum
local bto_raw = mtx.to_raw
local bmmult = mtx.mmult
local brmult = mtx.rmult
local bget = mtx.get
local bshape = mtx.shape
local bfrom_raw = mtx.from_raw

local validate = require("santoku.validate")
local isnumber = validate.isnumber
local hasmeta = validate.hasmetatable
local hasindex = validate.hasindex
local ge = validate.ge

local tbl = require("santoku.table")
local assign = tbl.assign

local arr = require("santoku.array")
local acat = arr.concat

local sformat = string.format

local function matrix (t, n, m)

  if hasmeta(t, mt_matrix) then
    if n ~= nil then
      local t0 = matrix(m - n + 1, bcolumns(t))
      bcopy(t0, t, n, m, 1)
      return t0
    else
      local t0 = matrix(brows(t), bcolumns(t))
      bcopy(t0, t, 1, brows(t), 1)
      return t0
    end
  end

  if type(t) == "string" then
    return bfrom_raw(t, n)
  end

  if type(t) == "number" and type(n) == "number" then
    return bmatrix(t, n)
  end

  if type(t) ~= "table" then
    error("Unexpected non-table argument to matrix: " .. type(t))
  end

  if #t < 0 then
    error("Can't create a matrix with fewer than 0 rows")
  end

  if type(t[1]) ~= nil and type(t[1]) ~= "table" then
    error("Unexpected non-table argument to matrix: " .. type(t[1]))
  end

  if t[1] and #t[1] < 0 then
    error("Can't create a matrix with fewer than 0 columns")
  end

  local m = matrix(#t, t[1] and #t[1] or 0)

  local rows, columns = bshape(m)

  for i = 1, rows do
    for j = 1, columns do
      bset(m, i, j, t[i][j])
    end
  end

  return m

end

local function extend (m, t, rowstart, rowend)

  if getmetatable(t) == mt_matrix then
    local mrows = brows(m)
    rowstart = rowstart or 1
    rowend = rowend or brows(t)
    breshape(m, brows(m) + rowend - rowstart + 1, bcolumns(m))
    bcopy(m, t, rowstart, rowend, mrows + 1)
    return m
  end

  if type(t) == "string" then
    bextend_raw(m, t)
    return m
  end

  if type(t) == "number" then
    breshape(m, brows(m) + t, bcolumns(m))
    return m
  end

  if type(t) ~= "table" then
    error("Unexpected non-table argument to extend: " .. type(t))
  end

  if type(t[1]) == "table" then

    local rows = brows(m)

    breshape(m, brows(m) + #t, bcolumns(m))

    for i = 1, #t do
      for j = 1, bcolumns(m) do
        bset(m, rows + i, j, t[i][j])
      end
    end

  else

    breshape(m, brows(m) + 1, bcolumns(m))

    for i = 1, #t do
      bset(m, brows(m), i, t[i])
    end

  end

  return m

end

local function set (m, r, c, v)
  assert(isnumber(r))
  assert(ge(r, 1))
  if isnumber(c) then
    bset(m, r, c, v)
    return m
  else
    assert(hasindex(c))
    for i = 1, #c do
      bset(m, r, i, c[i])
    end
    return m
  end
end

local function to_raw (m, rowstart, rowend)
  if rowstart == nil and rowend == nil then
    rowstart = 1
    rowend = brows(m)
  elseif rowstart ~= nil and rowend == nil then
    rowend = rowstart
  end
  return bto_raw(m, rowstart, rowend)
end

local function sum (m, rowstart, rowend)
  if rowstart == nil and rowend == nil then
    rowstart = 1
    rowend = brows(m)
  elseif rowstart ~= nil and rowend == nil then
    rowend = rowstart
  end
  return bsum(m, rowstart, rowend)
end

local function add (a, b, c, d)
  local rowstart = 1
  local rowend = brows(a)
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
  bradd(a, rowstart, rowend, add)
  return a
end

local function exp (a, b, c, d)
  local rowstart = 1
  local rowend = brows(a)
  local exp = nil
  if b and c and d then
    rowstart = b
    rowend = c
    exp = d
  elseif b and c then
    rowstart = b
    rowend = b
    exp = c
  elseif b then
    exp = b
  end
  bexp(a, rowstart, rowend, exp)
  return a
end

local function multiply (a, b, c, d, e)
  if getmetatable(b) == mt_matrix then
    bmmult(a, b, c, d, e)
    return c
  else
    local rowstart = 1
    local rowend = brows(a)
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
    brmult(a, rowstart, rowend, mult)
    return a
  end
end

local function average (m, d, row)
  bsums(m, d, row)
  multiply(d, row, 1 / brows(m))
  return d
end

local function normalize (m, rowstart, rowend)
  if rowstart == nil and rowend == nil then
    rowstart = 1
    rowend = brows(m)
  elseif rowstart ~= nil and rowend == nil then
    rowend = rowstart
  end
  for i = rowstart, rowend do
    multiply(m, i, 1 / bmagnitude(m, i))
  end
end

mt_matrix.__tostring = function (m)
  local out = { "matrix(", brows(m), ", ", bcolumns(m), ") " }
  for i = 1, brows(m) do
    for j = 1, bcolumns(m) do
      out[#out + 1] = sformat("%.2f", bget(m, i, j))
      out[#out + 1] = " "
    end
    out[#out + 1] = "// "
  end
  out[#out] = nil
  return acat(out)
end

return assign({
  matrix = matrix,
  average = average,
  normalize = normalize,
  multiply = multiply,
  extend = extend,
  to_raw = to_raw,
  set = set,
  sum = sum,
  add = add,
  exp = exp,
}, mtx, false)
