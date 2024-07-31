# Now

- CLI command to evaluate SBERT against a dataset

- Split test/train at load sentences. Load train first normally, then use train
  modeler to model test sentences (this way test is totally unseen)
- Allow passing multiple files to load sentences (merge them)

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
