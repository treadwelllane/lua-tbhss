local bitmap = require("santoku.bitmap")
local tm = require("santoku.tsetlin")
local err = require("santoku.error")

local function create_clustered (db, args)
  return db.db.transaction(function ()

    print("Creating clustered bitmaps")

    local clusters_model = db.get_clusters_model_by_name(args.clusters)

    if not clusters_model or clusters_model.clustered ~= 1 then
      err.error("Embeddings not clustered")
    end

    local bitmaps_model = db.get_bitmaps_model_by_name(args.name)

    if not bitmaps_model then
      local id = db.add_bitmaps_model(args.name, "clustered", clusters_model.id, {
        clusters = args.clusters,
        min_similarity = args.min_similarity,
        min_set = args.min_set,
        max_set = args.max_set,
      })
      bitmaps_model = db.get_bitmaps_model_by_id(id)
      assert(bitmaps_model, "this is a bug! bitmaps model not created")
    end

    if bitmaps_model.created == 1 then
      err.error("Bitmaps already created")
    end

    for id_embedding = 1, db.get_total_embeddings(clusters_model.id_embeddings_model) do
      local bm = bitmap.create()
      for c in db.get_nearest_clusters_by_id(
        clusters_model.id, id_embedding,
        args.min_set, args.max_set, args.min_similarity)
      do
        bitmap.set(bm, c.id)
      end
      db.add_bitmap(bitmaps_model.id, id_embedding, bitmap.raw(bm, clusters_model.clusters))
    end

    db.set_bitmaps_created(bitmaps_model.id)
    print("Persisted bitmaps")

  end)
end

local function get_clustered ()
  err.error("unimplemented", "get_clustered")
end

local function create_encoded (db, args)
  return db.db.transaction(function ()

    print("Creating encoded bitmaps")

    local encoder_model = db.get_encoder_model_by_name(args.encoder)

    if not encoder_model or encoder_model.created ~= 1 then
      err.error("Encoder model not found")
    end

    local embeddings_model = db.get_embeddings_model_by_id(encoder_model.id_embeddings_model)

    if not embeddings_model or embeddings_model.loaded ~= 1 then
      err.error("Embeddings model not loaded")
    end

    local bitmaps_model = db.get_bitmaps_model_by_name(args.name)

    if not bitmaps_model then
      local id = db.add_bitmaps_model(args.name, "encoded", encoder_model.id, args)
      bitmaps_model = db.get_bitmaps_model_by_id(id)
      assert(bitmaps_model, "this is a bug! bitmaps model not created")
    end

    if bitmaps_model.created == 1 then
      err.error("Bitmaps already created")
    end

    local encoder = db.get_encoder(encoder_model.id)

    if not encoder then
      err.error("Couldn't load encoder")
    end

    for id_embedding = 1, db.get_total_embeddings(embeddings_model.id) do
      local e = db.get_embedding(embeddings_model.id, id_embedding)
      -- TODO: predict could return a santoku.bitmap
      local bm = tm.predict(encoder, e)
      db.add_bitmap(bitmaps_model.id, id_embedding, bm)
    end

    db.set_bitmaps_created(bitmaps_model.id)
    print("Persisted bitmaps")

  end)
end

local function get_encoded ()
  err.error("unimplemented", "get_encoded")
end

return {
  create_clustered = create_clustered,
  create_encoded = create_encoded,
  get_clustered = get_clustered,
  get_encoded = get_encoded,
}
