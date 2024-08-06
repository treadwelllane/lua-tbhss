# Now

- Command to evaluate encoder on pre-loaded triplets dataset
    - Ex. evaluate on Multi NLI having only been trained on SNLI, the opposite,
      or to evaluate on the 500k training dataset after only training on
      dev/test, etc.

- Library interace: encoder and FAISS
- Pre-trained models for full SNLI dataset & 840B glove model

# Next

- Update README

- Improve performance:
    - Find initial centroids
    - Load embeddings
    - Pack datasets

- Option to encode for hamming vs jaccard (which would be useful when using the
  output as a semantic representation for a downstream classifier)

# Eventually

- Try different hashing mechanisms

- Hyperparameter search
- CLI command to evaluate SBERT against a dataset
- Three-way classifier predicting entailment, contradiction, or neutral

# Consider

- Fuzzy c-means clustering
- Fuzzy c-medoids clustering

- Use GloVe or FastText directly on sentence datasets first
- Finetuning helpers
