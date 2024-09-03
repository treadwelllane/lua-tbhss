# Now

- Don't store word embeddings as gigantic matrix in DB. Store as separate rows.
- Utility to prune a DB for downstream use (delete embeddings, sentences, unused
  words etc.)
    - Clusters currently still requires words to be loaded

- Library interace: encoder and FAISS
- Hyperparameter search
- Pre-trained models
- MTEB

# Next

- Update README

# Eventually

- Train on full SNLI and MNLI datasets (not just fully validated pairs)
- Allow repeat training of encoder (e.g. first pass on unvalidated data, second
  pass on validated data)

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
