# Now

- Allow early stopping when average change from (-10,-5) is less than eps
  differant than average change from (-5,0)
- Dont store word embeddings, just clusters
- Log training progress & performance
- Checkpoint to disk at various points so we can stop arbitrarily

- Library interface to inject cluster ids into sentence (for FTS enhancement)
- FAISS binding for bitmaps
- Pre-trained models for pos/neg sentiment analysis and semantic embeddings
- Pre-trained models for full SNLI dataset & 840B glove model
- MTEB

# Next

- Rescue k-means from history
- Update README

- Improve performance:
    - Find initial centroids
    - Load embeddings
    - Pack datasets

- Hyperparameter search

# Eventually

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

- Support selecting different hashing algorithms
    - Each dimension is a hash segment
    - All dimensions merged into single "segments" long hash

# Consider

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
