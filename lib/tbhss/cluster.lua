local err = require("santoku.err")
local blas = require("tbhss.blas")

local M = {}

-- TODO: Move to C
local function weighted_random_choice (probabilities, ids)
  local r = math.random()
  local sum = 0
  for i = 1, probabilities:columns() do
    sum = sum + probabilities:get(1, i)
    if r <= sum then
      return ids[i]
    end
  end
end

local function select_initial_clusters (word_matrix, n_clusters)

  local first = math.random(1, word_matrix:rows())

  local ignores = { [first] = true }
  local cluster_matrix = blas.matrix(word_matrix, first, first)
  local distance_matrix = blas.matrix(word_matrix:rows(), cluster_matrix:rows())

  print("Find Initial Centroids", cluster_matrix:rows(), first)

  for _ = 1, n_clusters - 1 do

    word_matrix:multiply(cluster_matrix, distance_matrix, { transpose_b = true })

    local sum = 0
    local distances = {}
    local ids = {}

    -- TODO: Move to C
    for i = 1, distance_matrix:rows() do
      if not ignores[i] then
        local maxval = distance_matrix:max(i)
        distances[#distances + 1] = 1 - maxval
        ids[#ids + 1] = i
        sum = sum + 1 - maxval
      end
    end

    distances = blas.matrix({ distances })
    distances:multiply(1 / sum)

    -- TODO: Move to C
    local i = weighted_random_choice(distances, ids)

    ignores[i] = true
    cluster_matrix:extend(word_matrix, i, i)
    distance_matrix:reshape(word_matrix:rows(), cluster_matrix:rows())

    print("Find Initial Centroids", cluster_matrix:rows(), i)

  end

  return cluster_matrix, distance_matrix

end

local function load_clusters_from_db (check, db, clustering)

  print("Loading word clusters from database")

  check(db.db:begin())

  local total_words = check(db.get_total_words(clustering.id_model))
  local distance_matrix = blas.matrix(total_words, clustering.clusters)
  local word_clusters_max = {}
  local word_clusters = {}

  check(db.get_word_clusters(clustering.id_model)):map(check):each(function (wc)

    if not word_clusters[wc.name] or wc.similarity > word_clusters_max[wc.name] then
      word_clusters[wc.name] = wc.id_cluster
      word_clusters_max[wc.name] = wc.similarity
    end

    distance_matrix:set(wc.id, wc.id_cluster, wc.similarity)

  end)

  check(db.db:commit())

  print("Loaded:", distance_matrix:rows())

  return word_clusters, distance_matrix

end

M.cluster_vectors = function (db, model, word_matrix, n_clusters, max_iterations)
  return err.pwrap(function (check)

    if not (model and model.words_loaded) then
      check(false, "Words not loaded")
    end

    local clustering = check(db.get_clustering(model.id, n_clusters))

    if clustering and clustering.words_clustered == 1 then
      return load_clusters_from_db(check, db, clustering)
    end

    print("Clustering")

    local cluster_matrix, distance_matrix = select_initial_clusters(word_matrix, n_clusters)
    local word_clusters = {}
    local cluster_average_matrix = blas.matrix(0, 0)

    local num_iterations = 1

    while true do

      local words_changed = 0
      local cluster_words = {}

      word_matrix:multiply(cluster_matrix, distance_matrix, { transpose_b = true })

      -- TODO: Move to C
      for i = 1, distance_matrix:rows() do
        local _, maxcol = distance_matrix:max(i)
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

      for i = 1, cluster_matrix:rows() do
        cluster_average_matrix:reshape(#cluster_words[i], word_matrix:columns())
        for j = 1, #cluster_words[i] do
          cluster_average_matrix:copy(word_matrix, cluster_words[i][j], cluster_words[i][j], j)
        end
        cluster_average_matrix:average(cluster_matrix, i)
      end

      cluster_matrix:normalize()

      print("Iteration", num_iterations, "Words Changed", words_changed)

      num_iterations = num_iterations + 1

      if max_iterations and num_iterations > max_iterations then
        break
      end

    end

    print("Persisting cluster distances")

    check(db.db:begin())

    local id_clustering = clustering
      and clustering.id
      or check(db.add_clustering(model.id, n_clusters))

    for i = 1, distance_matrix:rows() do
      for j = 1, distance_matrix:columns() do
        check(db.set_word_cluster_similarity(id_clustering, i, j, distance_matrix:get(i, j)))
      end
    end

    check(db.set_words_clustered(id_clustering, num_iterations))
    check(db.db:commit())

    return word_clusters, distance_matrix

  end)

end

return M
