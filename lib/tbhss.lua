local init_db = require("tbhss.db")
local bitmap = require("santoku.bitmap")
local str = require("santoku.string")
local num = require("santoku.num")
local arr = require("santoku.array")
local fs = require("santoku.fs")
local tm = require("santoku.tsetlin")
local err = require("santoku.error")

local function get_db (db_file)
  return type(db_file) == "string" and init_db(db_file) or db_file
end

local function split (s, max, words)
  words = words or {}
  local n = 1
  for w in str.gmatch(str.gsub(s, "[^%w%s]", ""), "%S+") do
    words[n] = str.lower(w)
    n = n + 1
    if max and n > max then
      break
    end
  end
  arr.clear(words, n)
  return words
end

local function tokenizer (db_file, bitmaps_model_name, positional_bits)

  local db = get_db(db_file)

  local bitmaps_model = db.get_bitmaps_model_by_name(bitmaps_model_name)

  if not bitmaps_model or bitmaps_model.created ~= 1 then
    err.error("Bitmaps model not loaded", bitmaps_model_name)
  end

  local bits

  if bitmaps_model.id_clusters_model == nil then
    bits = bitmaps_model.params.encoded_bits
  else
    local clusters_model = db.get_clusters_model_by_id(bitmaps_model.id_clusters_model)
    if not clusters_model then
      err.error("Clusters model not found", bitmaps_model.id_clusters_model)
    end
    bits = clusters_model.clusters
  end

  return {
    bits = bits,
    bitmaps_model = bitmaps_model,
    tokenize = function (s, max, terminate)
      return db.db.transaction(function ()
        local matches = {}
        local words = split(s, max)
        for i = 1, #words do
          local w = words[i]
          local bm_tok = db.get_bitmap(bitmaps_model.id, w)
          if not positional_bits then
            arr.push(matches, bm_tok or bitmap.create())
          else
            local pos = num.ceil((i - 1) * (positional_bits - 1) / (#words -1) + 1)
            local bm_pos = bitmap.create()
            bitmap.set(bm_pos, pos)
            if bm_tok then
              bitmap.extend(bm_pos, bm_tok, positional_bits + 1)
            end
            arr.push(matches, bm_pos)
          end
        end
        if #matches > 0 then
          if terminate then
            arr.push(matches, bitmap.create())
            arr.push(words, "")
          end
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

  local tokenizer = tokenizer(db_file, bitmaps_model.name, encoder_model.params.positional_bits)

  return {
    tokenizer = tokenizer,
    bitmaps_model = bitmaps_model,
    encoder_model = encoder_model,
    bits = encoder_model.params.encoded_bits,
    encode = function (s)
      return db.db.transaction(function ()
        local tokens = tokenizer.tokenize(s, encoder_model.params.max_words)
        if tokens then
          return bitmap.from_raw(tm.predict(t, #tokens, bitmap.raw_matrix(tokens, encoder_model.params.encoded_bits)))
        end
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
    normalize = function (s, min_set, max_set, min_similarity, return_table)
      return db.db.transaction(function ()
        local tokens = {}
        for w in str.gmatch(s, "%S+") do
          for c in db.get_nearest_clusters_by_word(
            clusters_model.id, str.lower(w),
            min_set, max_set, min_similarity)
          do
            arr.push(tokens, c.id)
          end
        end
        return return_table and tokens or arr.concat(tokens, " ")
      end)
    end,
  }

end

return {
  encoder = encoder,
  normalizer = normalizer,
  tokenizer = tokenizer,
  split = split,
}
