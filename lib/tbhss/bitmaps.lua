local bitmap = require("tbhss.bitmaps.bitmap")
local bcreate = bitmap.create
local bset = bitmap.set

local function create_bitmaps (words, word_clusters, bitmap_size)

  local word_bitmaps = {}

  for i = 1, #words do
    local bm = bcreate(bitmap_size)
    bset(bm, word_clusters[words[i]])
    word_bitmaps[words[i]] = bm
  end

  return word_bitmaps

end

return {
  create_bitmaps = create_bitmaps
}
