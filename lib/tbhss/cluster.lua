local err = require("santoku.error")
local error = err.error
local bm = require("santoku.bitmap")
local mtx = require("santoku.matrix")
local rand = require("santoku.random")

-- TODO: Move to C
local function weighted_random_choice (probabilities, ids)
  local r = rand.fast_random() / rand.fast_max
  local sum = 0
  for i = 1, mtx.columns(probabilities) do
    sum = sum + mtx.get(probabilities, 1, i)
    if r <= sum then
      return ids[i]
    end
  end
end

local function select_initial_clusters (word_matrix, n_clusters)

  local first = rand.fast_random() % mtx.rows(word_matrix) + 1

  local ignores = { [first] = true }
  local cluster_matrix = mtx.create(word_matrix, first, first)
  local distance_matrix = mtx.create(mtx.rows(word_matrix), mtx.rows(cluster_matrix))
  local distances = mtx.create(1, 0)
  local ids = {}
  local n_ids

  print("Find Initial Centroids", mtx.rows(cluster_matrix), first)

  for _ = 1, n_clusters - 1 do

    n_ids = 0
    mtx.multiply(word_matrix, cluster_matrix, distance_matrix, false, true)

    -- TODO: Move to C
    for i = 1, mtx.rows(distance_matrix) do
      if not ignores[i] then
        n_ids = n_ids + 1
        ids[n_ids] = i
        local maxval = mtx.rmax(distance_matrix, i)
        mtx.reshape(distances, 1, n_ids)
        mtx.set(distances, 1, n_ids, 1 - maxval)
      end
    end

    local sum = mtx.sum(distances)
    mtx.multiply(distances, 1 / sum)

    -- TODO: Move to C
    local i = weighted_random_choice(distances, ids)

    ignores[i] = true
    mtx.extend(cluster_matrix, word_matrix, i, i)
    mtx.reshape(distance_matrix, mtx.rows(word_matrix), mtx.rows(cluster_matrix))

    print("Find Initial Centroids", mtx.rows(cluster_matrix), i)

  end

  return cluster_matrix, distance_matrix

end

local function load_clusters_from_db (db, clustering)

  print("Loading word clusters from database")

  local total_words = db.get_total_words(clustering.id_model)
  local distance_matrix = mtx.create(total_words, clustering.clusters)

  for wc in db.get_word_clusters(clustering.id) do
    mtx.set(distance_matrix, wc.id_word, wc.id_cluster, wc.similarity)
  end

  print("Loaded:", mtx.rows(distance_matrix))

  return distance_matrix

end

local function cluster_vectors (db, model, word_matrix, n_clusters, max_iterations)
  return db.transaction(function ()

    if not (model and model.words_loaded) then
      error("Words not loaded")
    end

    local clustering = db.get_clustering(model.id, n_clusters)

    if clustering and clustering.words_clustered == 1 then
      return load_clusters_from_db(db, clustering)
    end

    print("Clustering")

    local cluster_matrix, distance_matrix = select_initial_clusters(word_matrix, n_clusters)
    local cluster_average_matrix = mtx.create(0, 0)
    local word_clusters = {}

    local num_iterations = 1

    while true do

      local words_changed = 0
      local cluster_words = {}

      mtx.multiply(word_matrix, cluster_matrix, distance_matrix, false, true)

      -- TODO: Move to C
      for i = 1, mtx.rows(distance_matrix) do
        local _, maxcol = mtx.rmax(distance_matrix, i)
        if word_clusters[i] ~= maxcol then
          words_changed = words_changed + 1
          word_clusters[i] = maxcol
        end
        cluster_words[maxcol] = cluster_words[maxcol] or {}
        cluster_words[maxcol][#cluster_words[maxcol] + 1] = i
      end

      if words_changed == 0 then
        print("Converged")
        break
      end

      for i = 1, mtx.rows(cluster_matrix) do
        mtx.reshape(cluster_average_matrix, #cluster_words[i], mtx.columns(word_matrix))
        for j = 1, #cluster_words[i] do
          mtx.copy(cluster_average_matrix, word_matrix, cluster_words[i][j], cluster_words[i][j], j)
        end
        mtx.average(cluster_average_matrix, cluster_matrix, i)
      end

      mtx.normalize(cluster_matrix)

      print("Iteration", num_iterations, "Words Changed", words_changed)

      num_iterations = num_iterations + 1

      if max_iterations and num_iterations > max_iterations then
        break
      end

    end

    print("Persisting cluster distances")

    local id_clustering = clustering
      and clustering.id
      or db.add_clustering(model.id, n_clusters)

    for i = 1, mtx.rows(distance_matrix) do
      for j = 1, mtx.columns(distance_matrix) do
        db.set_word_cluster_similarity(id_clustering, i, j, mtx.get(distance_matrix, i, j))
      end
    end

    db.set_words_clustered(id_clustering, num_iterations)

    return distance_matrix

  end)
end

local function create_bitmaps (distance_matrix, scale_factor, cutoff)

  scale_factor = scale_factor or 1
  local word_bitmaps = {}
  local n_words = mtx.rows(distance_matrix)
  local bitmap_size = mtx.columns(distance_matrix)

  local distances_scaled = mtx.create(1, bitmap_size)

  for i = 1, n_words do
    local b = bm.create()
    word_bitmaps[i] = b
    mtx.copy(distances_scaled, distance_matrix, i, i, 1)
    mtx.add(distances_scaled, 1)
    local minval = mtx.rmin(distances_scaled, 1)
    mtx.add(distances_scaled, -minval)
    mtx.exp(distances_scaled, scale_factor)
    local maxval = mtx.rmax(distances_scaled, 1)
    mtx.multiply(distances_scaled, 1 / maxval)
    for j = 1, bitmap_size do
      if mtx.get(distances_scaled, 1, j) < cutoff then
        bm.set(b, j)
      end
    end
  end

  return word_bitmaps

end

return {
  cluster_vectors = cluster_vectors,
  create_bitmaps = create_bitmaps,
}
