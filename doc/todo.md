# Now

- Library interace: encoder and FAISS
- Pre-trained models for full SNLI dataset & 840B glove model
- MTEB

# Next

- Update README

- Improve performance:
    - Find initial centroids
    - Load embeddings
    - Pack datasets

- Hyperparameter search

# Eventually

- Try different hashing mechanisms

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
