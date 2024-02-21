local mtx = require("santoku.matrix")
local matrix = mtx.matrix
local mreshape = mtx.reshape
local mcopy = mtx.copy
local mcolumns = mtx.columns
local maverage = mtx.average
local mget = mtx.get
local mmultiply = mtx.multiply
local mrmax = mtx.rmax
local msum = mtx.sum
local mextend = mtx.extend
local mset = mtx.set
local mrows = mtx.rows
local mnormalize = mtx.normalize

local err = require("santoku.error")
local error = err.error

local varg = require("santoku.varg")
local vtup = varg.tup

local rand = require("santoku.random")
local random = rand.num

-- TODO: Move to C
local function weighted_random_choice (probabilities, ids)
  local r = random()
  local sum = 0
  for i = 1, mcolumns(probabilities) do
    sum = sum + mget(probabilities, 1, i)
    if r <= sum then
      return ids[i]
    end
  end
end

local function select_initial_clusters (word_matrix, n_clusters)

  local first = random(1, mrows(word_matrix))

  local ignores = { [first] = true }
  local cluster_matrix = matrix(word_matrix, first, first)
  local distance_matrix = matrix(mrows(word_matrix), mrows(cluster_matrix))
  local distances = matrix(1, 0)
  local ids = {}
  local n_ids

  print("Find Initial Centroids", mrows(cluster_matrix), first)

  for _ = 1, n_clusters - 1 do

    n_ids = 0
    mmultiply(word_matrix, cluster_matrix, distance_matrix, false, true)

    -- TODO: Move to C
    for i = 1, mrows(distance_matrix) do
      if not ignores[i] then
        n_ids = n_ids + 1
        ids[n_ids] = i
        local maxval = mrmax(distance_matrix, i)
        mreshape(distances, 1, n_ids)
        mset(distances, 1, n_ids, 1 - maxval)
      end
    end

    local sum = msum(distances)
    mmultiply(distances, 1 / sum)

    -- TODO: Move to C
    local i = weighted_random_choice(distances, ids)

    ignores[i] = true
    mextend(cluster_matrix, word_matrix, i, i)
    mreshape(distance_matrix, mrows(word_matrix), mrows(cluster_matrix))

    print("Find Initial Centroids", mrows(cluster_matrix), i)

  end

  return cluster_matrix, distance_matrix

end

local function load_clusters_from_db (db, clustering)

  print("Loading word clusters from database")

  local total_words = db.get_total_words(clustering.id_model)
  local distance_matrix = matrix(total_words, clustering.clusters)

  for wc in db.get_word_clusters(clustering.id) do
    mset(distance_matrix, wc.id_word, wc.id_cluster, wc.similarity)
  end

  print("Loaded:", mrows(distance_matrix))

  return distance_matrix

end

local function cluster_vectors (db, model, word_matrix, n_clusters, max_iterations)

  db.begin()

  return vtup(function (ok, ...)
    if not ok then
      db.rollback()
      error(...)
    else
      db.commit()
      return ...
    end
  end, pcall(function ()

    if not (model and model.words_loaded) then
      error("Words not loaded")
    end

    local clustering = db.get_clustering(model.id, n_clusters)

    if clustering and clustering.words_clustered == 1 then
      return load_clusters_from_db(db, clustering)
    end

    print("Clustering")

    local cluster_matrix, distance_matrix = select_initial_clusters(word_matrix, n_clusters)
    local cluster_average_matrix = matrix(0, 0)

    local num_iterations = 1

    while true do

      local words_changed = 0
      local cluster_words = {}

      mmultiply(word_matrix, cluster_matrix, distance_matrix, false, true)

      -- TODO: Move to C
      for i = 1, mrows(distance_matrix) do
        local _, maxcol = mrmax(distance_matrix, i)
        cluster_words[maxcol] = cluster_words[maxcol] or {}
        cluster_words[maxcol][#cluster_words[maxcol] + 1] = i
      end

      if words_changed == 0 then
        print("Converged")
        break
      end

      for i = 1, mrows(cluster_matrix) do
        mreshape(cluster_average_matrix, #cluster_words[i], mcolumns(word_matrix))
        for j = 1, #cluster_words[i] do
          mcopy(cluster_average_matrix, word_matrix, cluster_words[i][j], cluster_words[i][j], j)
        end
        maverage(cluster_average_matrix, cluster_matrix, i)
      end

      mnormalize(cluster_matrix)

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

    for i = 1, mrows(distance_matrix) do
      for j = 1, mcolumns(distance_matrix) do
        db.set_word_cluster_similarity(id_clustering, i, j, mget(distance_matrix, i, j))
      end
    end

    db.set_words_clustered(id_clustering, num_iterations)

    return distance_matrix

  end))

end

return {
  cluster_vectors = cluster_vectors
}
