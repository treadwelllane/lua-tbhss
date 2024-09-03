local tm = require("santoku.tsetlin")
local err = require("santoku.error")
local bm = require("santoku.bitmap")

local modeler = require("tbhss.modeler")
local util = require("tbhss.util")

local function encoder (db_file, model_name, model_file)

  local db = util.get_db(db_file)
  local encoder_model = db.get_encoder_model_by_name(model_name)

  if not encoder_model then
    err.error("encoder model not found", model_name)
  elseif encoder_model.trained ~= 1 then
    err.error("encoder not trained", model_name)
  end

  local modeler = modeler.modeler(db, encoder_model.id_triplets_model)

  local t = tm.load(model_file)

  return {
    modeler = modeler,
    encode = function (s)
      local raw, bits = modeler.model(s)
      if raw then
        local fingerprint = bm.from_raw(raw, bits)
        local flipped = bm.copy(fingerprint)
        bm.flip(flipped, 1, bits)
        bm.extend(fingerprint, flipped, bits + 1)
        return tm.predict(t, bm.raw(fingerprint, bits * 2))
      end
    end,
  }

end

return {
  encoder = encoder,
  modeler = modeler.modeler,
}
