local serialize = require("santoku.serialize") -- luacheck: ignore
local mtx = require("santoku.matrix")
local err = require("santoku.error")
local rand = require("santoku.random")

-- TODO: Move to C
local function weighted_random_choice (probabilities, ids)
  local r = rand.num()
  local sum = 0
  for i = 1, mtx.columns(probabilities) do
    sum = sum + mtx.get(probabilities, 1, i)
    if r <= sum then
      return ids[i]
    end
  end
end

local function select_initial_clusters (word_matrix, n_clusters)

  local first = rand.num(1, mtx.rows(word_matrix))

  local ignores = { [first] = true }
  local cluster_matrix = mtx.create(word_matrix, first, first)
  local similarity_matrix = mtx.create(mtx.rows(word_matrix), mtx.rows(cluster_matrix))
  local similarities = mtx.create(1, 0)
  local ids = {}
  local n_ids

  print("Find Initial Centroids", mtx.rows(cluster_matrix), first)

  for _ = 1, n_clusters - 1 do

    n_ids = 0
    mtx.multiply(word_matrix, cluster_matrix, similarity_matrix, false, true)

    -- TODO: Move to C
    for i = 1, mtx.rows(similarity_matrix) do
      if not ignores[i] then
        n_ids = n_ids + 1
        ids[n_ids] = i
        local maxval = mtx.rmax(similarity_matrix, i)
        mtx.reshape(similarities, 1, n_ids)
        mtx.set(similarities, 1, n_ids, 1 - maxval)
      end
    end

    local sum = mtx.sum(similarities)
    mtx.multiply(similarities, 1 / sum)

    local i = weighted_random_choice(similarities, ids)

    ignores[i] = true
    mtx.extend(cluster_matrix, word_matrix, i, i)
    mtx.reshape(similarity_matrix, mtx.rows(word_matrix), mtx.rows(cluster_matrix))

    print("Find Initial Centroids", mtx.rows(cluster_matrix), i)

  end

  return cluster_matrix, similarity_matrix

end

-- TODO: Filter words in-place by deleting from word matrix instead of creating
-- a new matrix
local function filter_words (db, words_model, word_matrix, snli_name, word_idmap)
  local filtered = db.get_all_filtered_words(words_model.id, snli_name)
  if not (filtered and #filtered > 0) then
    err.error("Could not filter words. Does the SNLI dataset exist?", snli_name)
  end
  local n = 0
  local m0 = mtx.create(#filtered, words_model.dimensions)
  for i = 1, #filtered do
    n = n + 1
    local w = filtered[i]
    mtx.copy(m0, word_matrix, w.id, w.id, n)
    word_idmap[n] = w.id
  end
  return m0
end


local function find_furthest (similarity_matrix)
  local best_medoid, best_val
  for i = 1, mtx.rows(similarity_matrix) do
    local minval, mincol = mtx.rmin(similarity_matrix, i)
    if not best_medoid or minval < best_val then
      best_medoid, best_val = mincol, minval
    end
  end
  return best_medoid
end

local function total_similarity (
  word_matrix, cluster_words,
  medoid_matrix, medoid_idx,
  word_vector, cluster_vector, tmp_vector
)
  mtx.copy(cluster_vector, medoid_matrix, medoid_idx, medoid_idx, 1)
  local total = 0
  for i = 1, #cluster_words do
    local w = cluster_words[i]
    mtx.copy(word_vector, word_matrix, w, w, 1)
    total = total + mtx.dot(word_vector, cluster_vector, tmp_vector)
  end
  return total
end

local function perform_clustering (db, clusters_model, args)

  print("Clustering")

  local words_model = db.get_words_model_by_name(args.words)

  if not words_model or words_model.loaded ~= 1 then
    err.error("Words model not loaded", args.words)
  end

  local word_idmap = {}
  local word_matrix = mtx.create(db.get_word_embeddings(words_model.id), words_model.dimensions)

  if args.filter_words then
    word_matrix = filter_words(db, words_model, word_matrix, args.filter_words, word_idmap)
    print("Filtered words", mtx.rows(word_matrix))
  else
    for i = 1, mtx.rows(word_matrix) do
      word_idmap[i] = i
    end
  end

  if mtx.rows(word_matrix) < args.clusters then
    args.clusters = mtx.rows(word_matrix)
  end

  mtx.normalize(word_matrix)

  local cluster_matrix, similarity_matrix = select_initial_clusters(word_matrix, args.clusters)
  local word_clusters = {}
  local num_iterations = 1

  while true do

    local words_changed = 0
    local cluster_words = {}

    mtx.multiply(word_matrix, cluster_matrix, similarity_matrix, false, true)

    for i = 1, mtx.rows(similarity_matrix) do
      local _, maxcol = mtx.rmax(similarity_matrix, i)
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

    local word_vector = mtx.create(1, mtx.columns(word_matrix))
    local cluster_vector = mtx.create(1, mtx.columns(word_matrix))
    local tmp_vector = mtx.create(1, 1)

    for i = 1, mtx.rows(cluster_matrix) do
      if not cluster_words[i] then
        local furthest_medoid = find_furthest(similarity_matrix)
        mtx.copy(cluster_matrix, word_matrix, furthest_medoid, furthest_medoid, i)
      else
        local best_medoid, best_similarity
        for j = 1, #cluster_words[i] do
          local new_word = cluster_words[i][j]
          local new_similarity = total_similarity(
            word_matrix, cluster_words[i], word_matrix, new_word, word_vector, cluster_vector, tmp_vector)
          if not best_medoid or new_similarity > best_similarity then
            best_medoid = new_word
            best_similarity = new_similarity
          end
        end
        mtx.copy(cluster_matrix, word_matrix, best_medoid, best_medoid, i)
      end
    end

    print("Iteration", num_iterations, "Words Changed", words_changed)
    num_iterations = num_iterations + 1

  end

  print("Persisting cluster similarities")

  local id_model = clusters_model
    and clusters_model.id
    or db.add_clusters_model(args.name, words_model.id, args.clusters)

  local order = mtx.rorder(similarity_matrix, args.min, args.max, args.cutoff)

  for i = 1, #order do
    local o = order[i]
    for j = 1, #o do
      local t = o[j]
      db.set_word_cluster_similarity(id_model, word_idmap[i], t, mtx.get(similarity_matrix, i, t))
    end
  end

  db.set_words_clustered(id_model)

  return db.get_clusters_model_by_id(id_model)

end

local function create_clusters (db, args)
  return db.db.transaction(function ()
    local clusters_model = db.get_clusters_model_by_name(args.name)
    if not clusters_model or clusters_model.clustered ~= 1 then
      return perform_clustering(db, clusters_model, args)
    else
      err.error("Words already clustered")
    end
  end)
end

return {
  create_clusters = create_clusters,
}
