# Now

- Library interace: encoder and FAISS
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
