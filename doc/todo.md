# Now

- Move non-clustered bitmap model code to branch & delete

- Sinusoidal segment assignment

- Pre-trained encoders: SNLI & MutiNLI datasets with various settings shared as
  sqlite.db files with training data pruned

- FAISS

- Update README

# Later

- Allow word embeddings auto-encoder to be persisted
- Improve performance of loading glove embeddings. Write in C? Parallelize?
- Use GloVe or FastText directly on sentence datasets first
- Instead of strictly using sentence dataset words, include nearest N words to
  each word

- Move various inner loops to C (see cluster.lua TODOs)
- Fuzzy c-means clustering, update multi-cluster bitmap logic accordingly

# Eventually

- Finetuning helpers

- Consider only persisting word cluster distance matrices instead of individual
  distances
