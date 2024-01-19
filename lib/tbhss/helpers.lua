local M = {}

M.dot_product = function (a, b)
  local sum = 0
  for i = 1, #a do
    sum = sum + a[i] * b[i]
  end
  return sum
end

M.average = function (vs)
  local sums = {}
  for i = 1, #vs do
    for j = 1, #vs[i] do
      sums[j] = (sums[j] or 0) + vs[i][j]
    end
  end
  for i = 1, #sums do
    sums[i] = sums[i] / #vs
  end
  return sums
end

M.magnitude = function (t)
  return math.sqrt(M.dot_product(t, t))
end

M.normalize = function (f)
  local m = M.magnitude(f)
  for i = 1, #f do
    f[i] = f[i] / m
  end
end

M.random_normal = function ()
  local u1 = math.random()
  local u2 = math.random()
  local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
  return math.max(-1, math.min(1, z))
end

M.weighted_random_choice = function (probabilities, ids)
  local r = math.random()
  local sum = 0
  for i = 1, #probabilities do
    sum = sum + probabilities[i]
    if r <= sum then
      return ids[i]
    end
  end
end

return M
