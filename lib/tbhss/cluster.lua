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

M.cluster_vectors = function (word_matrix, n_clusters, max_iterations)

  local cluster_matrix, distance_matrix = select_initial_clusters(word_matrix, n_clusters)
  local word_clusters = {}
  local cluster_average_matrix = blas.matrix(0, 0)

  local n = 1

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

    print("Iteration", n, "Words Changed", words_changed)

    n = n + 1

    if max_iterations and n > max_iterations then
      break
    end

  end

  return word_clusters, distance_matrix, cluster_matrix

end

return M
