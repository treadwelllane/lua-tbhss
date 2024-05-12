local serialize = require("santoku.serialize") -- luacheck: ignore

local mtx = require("santoku.matrix")
local mcreate = mtx.create
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
local rand = require("santoku.random")
local words = require("tbhss.words")

-- TODO: Move to C
local function weighted_random_choice (probabilities, ids)
  local r = rand.num()
  local sum = 0
  for i = 1, mcolumns(probabilities) do
    sum = sum + mget(probabilities, 1, i)
    if r <= sum then
      return ids[i]
    end
  end
end

local function select_initial_clusters (word_matrix, n_clusters)

  local first = rand.num(1, mrows(word_matrix))

  local ignores = { [first] = true }
  local cluster_matrix = mcreate(word_matrix, first, first)
  local distance_matrix = mcreate(mrows(word_matrix), mrows(cluster_matrix))
  local distances = mcreate(1, 0)
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

local function cluster_words (db, clusters_model, args)

  print("Clustering")

  local words_model, word_matrix = words.get_words(db, args.words)

  if not words_model or words_model.loaded ~= 1 then
    err.error("Words model not loaded")
  end

  local cluster_matrix, distance_matrix = select_initial_clusters(word_matrix, args.clusters)
  local cluster_average_matrix = mcreate(0, 0)
  local word_clusters = {}

  local num_iterations = 1

  while true do

    local words_changed = 0
    local cluster_words = {}

    mmultiply(word_matrix, cluster_matrix, distance_matrix, false, true)

    -- TODO: Move to C
    for i = 1, mrows(distance_matrix) do
      local _, maxcol = mrmax(distance_matrix, i)
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

  end

  print("Persisting cluster distances")

  local id_model = clusters_model
    and clusters_model.id
    or db.add_clusters_model(args.name, words_model.id, args.clusters)

  for i = 1, mrows(distance_matrix) do
    for j = 1, mcolumns(distance_matrix) do
      db.set_word_cluster_similarity(id_model, i, j, mget(distance_matrix, i, j))
    end
  end

  db.set_words_clustered(id_model, num_iterations)

end

local function get_clusters (db, name)
  local model = db.get_clusters_model_by_name(name)
  if not model or not model.clustered then
    return
  end
  print("Loading word clusters from database")
  local total_words = db.get_total_words(model.id_words_model)
  local distance_matrix = mcreate(total_words, model.clusters)
  for wc in db.get_clusters(model.id) do
    mset(distance_matrix, wc.id_words, wc.id, wc.similarity)
  end
  print("Loaded:", mrows(distance_matrix))
  return model, distance_matrix
end

local function create_clusters (db, args)
  return db.db.transaction(function ()
    local clusters_model = db.get_clusters_model_by_name(args.name)
    if not clusters_model or clusters_model.clustered ~= 1 then
      return cluster_words(db, clusters_model, args)
    else
      err.error("Words already clustered")
    end
  end)

end

return {
  create_clusters = create_clusters,
  get_clusters = get_clusters,
}
