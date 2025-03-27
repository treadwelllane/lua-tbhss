local util = require("tbhss.util")
local modeler = require("tbhss.modeler")
local classifier = require("tbhss.classifier")
local encoder = require("tbhss.encoder")

local function open_encoder (db_file, name)
  local db = util.get_db(db_file)
  return encoder.open(db, name)
end

local function open_classifier (db_file, name)
  local db = util.get_db(db_file)
  return classifier.open(db, name)
end

local function open_modeler (db_file, name)
  local db = util.get_db(db_file)
  return modeler.open(db, name)
end

return {
  modeler = open_modeler,
  classifier = open_classifier,
  encoder = open_encoder,
}
