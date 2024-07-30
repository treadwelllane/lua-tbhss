-- TODO:
-- Grid or random based on args.search
-- Store encoder epoch scores in the db
local function search_hyperparams (--[[db,]] args)
  print(require("santoku.serialize")(args))
end

return {
  search_hyperparams = search_hyperparams
}
