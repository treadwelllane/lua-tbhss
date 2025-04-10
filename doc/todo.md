# Now

- Better handling of round_multiple(x, 128). Currently, hidden and visible
  features are rounded to the next multiple of 128 so that tsetlin doesn't
  complain. Perhaps this should be configurable?

- Tokenizer:
    - Add a .filter() function, accepting a list of token IDs to filter tokens
      by. Keep only these tokens.
    - Discrete-sinusoidal positional encoding
        - User-selectable wavelength and buckets
        - Configurable apply to uni/bi/tri/etc-grams (e.g. specify 1 for
          unigrams, 2 for unigrams and bigrams, etc.)
        - Not applied to cgrams

- Refine explore api
    - rename explore imdb/snli to explore classifier/encoder (allowing generic
      datasets created via the process command)

- Log training progress & performance
- Checkpoint to disk at various points so we can stop arbitrarily

- FAISS binding for bitmaps
- Pre-trained classifier models (imdb, what else?)
- Pre-trained encoder models (snli, what else?)

- MTEB

# Next

- Dont store word embeddings, just clusters
- Library interface to inject cluster ids into sentence (for FTS enhancement)
- Rescue k-means from history
- Update README

# Eventually

# Consider

- Re-implement BPE. Merge alnum with alnum, punct with punct, and flatten all
  whitespace into single space

- Multi-granular DBSCAN
    - Compute fuzzy membership after initial dbscan
        - For each point, p, for each nearest point, n, belonging to a differnet
          cluster, consider p as belonging to n's cluster with a membership %
          equal to the similarity of p and n
    - Run DBSCAN with varying eps/min_pts values and (like in k-means/medoids)
      represent each token with multiple (in this case equally-weighted) cluster
      ids.

- Fuzzy c-means clustering
- Fuzzy c-medoids clustering

- Use GloVe or FastText directly on sentence datasets first
- Finetuning helpers

- Command to evaluate encoder on pre-loaded triplets dataset
    - Ex. evaluate on Multi NLI having only been trained on SNLI, the opposite,
      or to evaluate on the 500k training dataset after only training on
      dev/test, etc.

- Option to encode for hamming vs jaccard (which might be useful when using the
  output as a semantic representation for a downstream classifier)
