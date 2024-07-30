# Now

- Hyperparameter search

# Later

- Pre-trained encoders: SNLI & MutiNLI datasets with various settings shared as
  sqlite.db files with training data pruned

- FAISS

- Update README

- Move various inner loops to C (see cluster.lua TODOs)
- Fuzzy c-means clustering
- Fuzzy c-medoids clustering

# Eventually

- Finetuning helpers
- Classifier using pairwise xor predicting entailment, contradiction, or neutral
- Use GloVe or FastText directly on sentence datasets first
- Improve performance of loading glove embeddings. Write in C? Parallelize?
