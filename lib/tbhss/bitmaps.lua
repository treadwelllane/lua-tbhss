local bitmap = require("santoku.bitmap")
local bcreate = bitmap.create
local bset = bitmap.set

local mtx = require("santoku.matrix")
local matrix = mtx.matrix
local mrows = mtx.rows
local mcolumns = mtx.columns
local mget = mtx.get
local mcopy = mtx.copy
local mexp = mtx.exp
local mmult = mtx.multiply
local mrmax = mtx.rmax
local madd = mtx.add

local rand = math.random

local function create_bitmaps (distance_matrix, scale_factor)

  scale_factor = scale_factor or 1
  local word_bitmaps = {}
  local n_words = mrows(distance_matrix)
  local bitmap_size = mcolumns(distance_matrix)

  local distances_scaled = matrix(1, bitmap_size)

  for i = 1, n_words do
    local bm = bcreate(bitmap_size)
    word_bitmaps[i] = bm
    mcopy(distances_scaled, distance_matrix, i, i, 1)
    local _, maxcol = mrmax(distances_scaled, 1)
    madd(distances_scaled, 1)
    mmult(distances_scaled, 1 / 2)
    mexp(distances_scaled, scale_factor)
    bset(bm, maxcol)
    -- TODO: use weighted random choice implemented in c
    for j = 1, bitmap_size do
      if rand() ^ scale_factor < mget(distances_scaled, 1, j) then
        bset(bm, j)
      end
    end
  end

  return word_bitmaps

end

return {
  create_bitmaps = create_bitmaps
}
