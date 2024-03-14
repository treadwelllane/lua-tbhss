# Extending the Base Model

## Supporting Multiple Clusters per Term

- Words could be associated with J clusters instead a single cluster based on a
  fuzzy c-means clustering algorithm

## Allowing for Unique Word Representations

- A potential problem is that all words in a cluster have the same bitmap
  representation

- To allow for more unique representations, a number of additional bits can be
  set in the word bitmaps

- For each word, consider its (word_cluster_rank) as it's proximity to the
  cluster centroid represented as max-normalization of word distances within a
  cluster to the clusters centroid, and set a proportional number of additional
  bits:

    (word_cluster_rank) =
        (word_distance ^ scale) / (max_distance ^ scale)

    (num_additional_bits) =
        (min_additional_bits) +
        (word_cluster_rank * (max_additional_bits - min_additional_bits))

- Set (num_additional_bits) selected as a distance from the term in question to
  another centroid following a normal distributin distribution:

    (neighbor_distance) =
        abs(rand_normal()) / (additional_bit_deviation) * (max_neighbor_distance)

- In summary:
  - Set additional bits in a words bitmap correspondong to the nearest
    neighboring centroids of that word
  - For words that are close to their centroid, select fewer additional bits
  - Select bits based on a randomly generated centroid distance

- As a result of this, words are represented more uniquely, with words
  well-aligned to their cluster represented in fewer bits, and words that are
  less well aligned dto their cluster represented in more bits

## Topic-Frequency IDF (Topics, not Terms)

- TODO: Can documents be simply re-written as a sequence of cluster IDs and then
  have existing TF-IDF implementations take over? Users could use this lib to
  produce a set of cluster IDs for words based on the glove data and then
  basically re-write documents looking up words.

- Translate words to single main cluster number, translate words to multiple
  numbers corresponding to most similar clusters

## Adding Token Context

- TODO: How to add additional data representing token context, part of speech
  tagging, named entities, etc.

## Bloom Filter Query Optimization

- TODO: Is there a way to merge a corpus of sentence bitmaps into a hierarchy of
  bloom filters as to improve performance of nearest neighbor search? In other
  words, can we use bloom filters to, given an input sentence, eliminate a
  subset of documents that would have Jaccard Similarities of 0?

## Next Token Prediction

- Input: sequence of words
- Encode: sequence of word-cluster bitmaps
- Compress: sequence of sentence bitmaps
- Feed forward: concatenated N sentence bitmaps, producing cluster number
- Decode: concatenate cluster number to N sentence bitmaps, producing word?
