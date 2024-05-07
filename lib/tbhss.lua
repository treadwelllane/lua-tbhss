local init_db = require("tbhss.db")
local bitmap = require("santoku.bitmap")
local str = require("santoku.string")
local arr = require("santoku.array")
local err = require("santoku.error")

local function bitmapper_clustered (db, bitmaps_model)

  local clusters_model = db.get_clusters_model_by_name(bitmaps_model.model_params.clusters)

  if not clusters_model then
    err.error("clusters model not found", bitmaps_model.name, bitmaps_model.model_params.clusters)
  end

  return {
    bits = clusters_model.clusters,
    encode = function (s)
      local b = bitmap.create()
      for w in str.gmatch(s, "%S+") do
        local b0 = db.get_bitmap_clustered(bitmaps_model.id, str.lower(w))
        if b0 then
          bitmap["or"](b, b0)
        end
      end
      return b
    end,
  }

end

local function bitmapper_encoded (db, bitmaps_model)

  local encoder_model = db.get_encoder_model_by_name(bitmaps_model.model_params.encoder)

  if not encoder_model then
    err.error("encoder model not found", bitmaps_model.name, bitmaps_model.model_params.encoder)
  end

  return {
    bits = encoder_model.params.bits,
    encode = function (s)
      local b = bitmap.create()
      for w in str.gmatch(s, "%S+") do
        local b0 = db.get_bitmap_encoded(bitmaps_model.id, str.lower(w))
        if b0 then
          bitmap["or"](b, b0)
        end
      end
      return b
    end,
  }

end

local function bitmapper (db_file, model_name)

  local db = init_db(db_file)
  local bitmaps_model = db.get_bitmaps_model_by_name(model_name)

  if not bitmaps_model then
    err.error("model not found", model_name)
  elseif bitmaps_model.created ~= 1 then
    err.error("bitmaps not created", model_name)
  end

  if bitmaps_model.model_type == "clustered" then
    return bitmapper_clustered(db, bitmaps_model)
  elseif bitmaps_model.model_type == "encoded" then
    return bitmapper_encoded(db, bitmaps_model)
  else
    err.error("unexpected bitmaps model type", model_name, bitmaps_model.model_type)
  end

end

local function normalizer (db_file, model_name)

  local db = init_db(db_file)

  local clusters_model = db.get_clusters_model_by_name(model_name)

  if not clusters_model then
    err.error("clusters model not found", model_name)
  end

  return {
    normalize = function (s, min_set, max_set, min_similarity)
      local matches = {}
      return (str.gsub(s, "%S+", function (w)
        arr.clear(matches)
        for c in db.get_nearest_clusters_by_word(
          clusters_model.id, str.lower(w),
          min_set, max_set, min_similarity)
        do
          matches[#matches + 1] = c.id
        end
        return arr.concat(matches, " ")
      end))
    end,
  }

end

return {
  bitmapper = bitmapper,
  normalizer = normalizer,
}
