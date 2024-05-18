local init_db = require("tbhss.db")
local bitmap = require("santoku.bitmap")
local str = require("santoku.string")
local arr = require("santoku.array")
local fs = require("santoku.fs")
local tm = require("santoku.tsetlin")
local err = require("santoku.error")

local function get_db (db_file)
  return type(db_file) == "string" and init_db(db_file) or db_file
end

local function tokenizer (db_file, bitmaps_model_name)

  local db = get_db(db_file)

  local bitmaps_model = db.get_bitmaps_model_by_name(bitmaps_model_name)

  if not bitmaps_model or bitmaps_model.created ~= 1 then
    err.error("Bitmaps model not loaded", bitmaps_model_name)
  end

  local clusters_model = db.get_clusters_model_by_id(bitmaps_model.id_clusters_model)

  if not clusters_model then
    err.error("Clusters model not found", bitmaps_model.id_clusters_model)
  end

  return {
    clusters_model = clusters_model,
    bitmaps_model = bitmaps_model,
    tokenize = function (s)
      return db.db.transaction(function ()
        local matches = {}
        local words = {}
        for w in str.gmatch(str.gsub(s, "[^%w%s]", ""), "%S+") do
          w = str.lower(w)
          local bm = db.get_bitmap(bitmaps_model.id, w)
          if bm then
            arr.push(matches, bm)
            arr.push(words, w)
          end
        end
        if #matches > 0 then
          arr.push(matches, bitmap.create())
          arr.push(words, "")
          return matches, words, s
        end
      end)
    end,
  }

end

local function encoder (db_file, model_name)

  local db = get_db(db_file)
  local encoder_model = db.get_encoder_model_by_name(model_name)

  if not encoder_model then
    err.error("encoder model not found", model_name)
  elseif encoder_model.trained ~= 1 then
    err.error("encoder not trained", model_name)
  end

  -- TODO: read directly from sqlite without temporary file
  local fp = fs.tmpname()
  fs.writefile(fp, encoder_model.model)
  local t = tm.load(fp)
  fs.rm(fp)

  local bitmaps_model = db.get_bitmaps_model_by_id(encoder_model.id_bitmaps_model)

  if not bitmaps_model then
    err.error("Bitmaps model not found", encoder_model.id_bitmaps_model)
  end

  local tokenizer = tokenizer(db_file, bitmaps_model.name)

  return {
    tokenizer = tokenizer,
    bitmaps_model = bitmaps_model,
    encoder_model = encoder_model,
    bits = encoder_model.params.output_bits,
    encode = function (s)
      return db.db.transaction(function ()
        return bitmap.from_raw(tm.predict(t, tokenizer.tokenize(s)))
      end)
    end,
  }

end

local function normalizer (db_file, model_name)

  local db = get_db(db_file)
  local clusters_model = db.get_clusters_model_by_name(model_name)

  if not clusters_model then
    err.error("clusters model not found", model_name)
  end

  return {
    clusters_model = clusters_model,
    normalize = function (s, min_set, max_set, min_similarity)
      return db.db.transaction(function ()
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
      end)
    end,
  }

end

return {
  encoder = encoder,
  normalizer = normalizer,
  tokenizer = tokenizer,
}
