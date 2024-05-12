local bitmap = require("santoku.bitmap")
local tm = require("santoku.tsetlin")
local err = require("santoku.error")

local function create_bitmaps (db, args)
  return db.db.transaction(function ()

    print("Creating bitmaps")

    local clusters_model = db.get_clusters_model_by_name(args.clusters)

    if not clusters_model or clusters_model.clustered ~= 1 then
      err.error("Words not clustered")
    end

    local bitmaps_model = db.get_bitmaps_model_by_name(args.name)

    if not bitmaps_model then
      local id = db.add_bitmaps_model(args.name, clusters_model.id, {
        clusters = args.clusters,
        min_similarity = args.min_similarity,
        min_set = args.min_set,
        max_set = args.max_set,
      })
      bitmaps_model = db.get_bitmaps_model_by_id(id)
      err.assert(bitmaps_model, "This is a bug! Bitmaps model not created")
    end

    if bitmaps_model.created == 1 then
      err.error("Bitmaps already created")
    end

    for id_words = 1, db.get_total_words(clusters_model.id_words_model) do
      local bm = bitmap.create()
      for c in db.get_nearest_clusters_by_id(
        clusters_model.id, id_words,
        args.min_set, args.max_set, args.min_similarity)
      do
        bitmap.set(bm, c.id)
      end
      db.add_bitmap(bitmaps_model.id, id_words, bitmap.raw(bm, clusters_model.clusters))
    end

    db.set_bitmaps_created(bitmaps_model.id)
    print("Persisted bitmaps")

  end)
end

return {
  create_bitmaps = create_bitmaps,
}
