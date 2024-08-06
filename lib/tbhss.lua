local fs = require("santoku.fs")
local tm = require("santoku.tsetlin")
local err = require("santoku.error")

local modeler = require("tbhss.modeler")
local util = require("tbhss.util")

local function encoder (db_file, model_name)

  local db = util.get_db(db_file)
  local encoder_model = db.get_encoder_model_by_name(model_name)

  if not encoder_model then
    err.error("encoder model not found", model_name)
  elseif encoder_model.trained ~= 1 then
    err.error("encoder not trained", model_name)
  end

  local modeler = modeler.modeler(db, encoder_model.id_triplets_model)

  -- TODO: read directly from sqlite without temporary file
  local fp = fs.tmpname()
  fs.writefile(fp, encoder_model.model)
  local t = tm.load(fp)
  fs.rm(fp)

  return {
    modeler = modeler,
    encode = function (s)
      return db.db.transaction(function ()
        local fingerprint = modeler.model(s)
        if fingerprint then
          return tm.predict(t, fingerprint)
        end
      end)
    end,
  }

end

return {
  encoder = encoder,
  modeler = modeler.modeler,
}
