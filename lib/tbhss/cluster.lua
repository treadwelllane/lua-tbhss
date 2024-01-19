local helpers = require("tbhss.helpers")

local M = {}

local function find_nearest_centroid (word, vector, centroids, nearest_cache)

  local last = nearest_cache and nearest_cache[word]

  if last then

    local new = centroids[#centroids]
    local v = helpers.dot_product(vector, new)

    if v > last.value then
      last.value = v
      last.vector = new
      last.idx = #centroids
    end

    return last.idx, last.vector

  else

    local max_idx = nil
    local max_value = -1
    local max_vector = nil

    for i = 1, #centroids do

      local v = helpers.dot_product(vector, centroids[i])

      if v > max_value then
        max_idx = i
        max_value = v
        max_vector = centroids[i]
      end

    end

    if nearest_cache then
      nearest_cache[word] = { value = max_value, vector = max_vector, idx = max_idx }
    end

    return max_idx, max_vector

  end

end

local function select_initial_centroids (words, word_vectors, n_clusters)

  local first = math.random(1, #words)

  local ignores = { [first] = true }
  local centroids = { word_vectors[words[first]] }
  local centroid_words = { words[first] }

  print("Find Initial Centroids", #centroids, words[first])

  local nearest_cache = {}

  for _ = 1, n_clusters - 1 do

    local distances = {}
    local probabilities = {}
    local ids = {}

    local sum = 0

    for i = 1, #words do
      if not ignores[i] then
        local _, nearest = find_nearest_centroid(i, word_vectors[words[i]], centroids, nearest_cache)
        distances[#distances + 1] = helpers.dot_product(word_vectors[words[i]], nearest)
        ids[#ids + 1] = i
        sum = sum + (1 - distances[#distances])
      end
    end

    for i = 1, #distances do
      probabilities[i] = (1 - distances[i]) / sum
    end

    local i = helpers.weighted_random_choice(probabilities, ids)

    ignores[i] = true
    centroids[#centroids + 1] = word_vectors[words[i]]
    centroid_words[#centroid_words + 1] = words[i]

    print("Find Initial Centroids", #centroids, words[i])

  end

  return centroids, centroid_words

end

M.cluster_vectors = function (words, word_vectors, n_clusters)

  local centroids = select_initial_centroids(words, word_vectors, n_clusters)
  local word_numbers = {}

  local n = 1

  while true do

    local words_changed = 0
    local centroid_words = {}

    for i = 1, #words do

      local idx = find_nearest_centroid(i, word_vectors[words[i]], centroids)

      if word_numbers[words[i]] ~= idx then
        words_changed = words_changed + 1
        word_numbers[words[i]] = idx
      end

      centroid_words[idx] = centroid_words[idx] or {}
      centroid_words[idx][#centroid_words[idx] + 1] = words[i]

    end

    if words_changed == 0 then
      print("Converged")
      break
    end

    for i = 1, #centroids do

      local member_vectors = {}

      for j = 1, #centroid_words[i] do
        member_vectors[#member_vectors + 1] = word_vectors[centroid_words[i][j]]
      end

      centroids[i] = helpers.average(member_vectors)

      helpers.normalize(centroids[i])

    end

    print("Iteration", n, "Words Changed", words_changed)

    n = n + 1

  end

  return word_numbers

end

return M
