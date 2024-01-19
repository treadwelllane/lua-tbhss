local bitmap = require("tbhss.bitmaps.bitmap")

local M = {}

M.create_bitmaps = function (words, word_clusters, bitmap_size)

  local word_bitmaps = {}

  for i = 1, #words do
    word_bitmaps[words[i]] = bitmap.create(bitmap_size)
    word_bitmaps[words[i]]:set(word_clusters[words[i]])
  end

  return word_bitmaps

end

return M
