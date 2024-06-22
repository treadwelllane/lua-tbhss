# Now

x Word loading:
  x Sanitized and de-duped (if necessary) per tbhss.split

x Word clustering:
  x New id_sentences_model which is set to null when creating clusters directly
    or to the sentence_model.id when created per sentence loading

x Sentence modeling:
  x Separate sentence and sentence_pair tables
  x Sanitized on load
  x Word IDs mapped via sentence_words table (independent IDs from words model)
  x Sanitized word IDs stored as json_array "tokens"
  x Clusters are created on the fly
  x "tokens" array is updated to include cluster IDs (as negatives) per configuration
  x Stringified tokens arrays are inserted into FTS5
  - Bitmaps are created using tokens arrays and fts5vocab
  - First half of bitmap hashes the de-duped SET of tokens, and then aggregates
    bit counts using bm25 weights
  - Second half of bitmap hashes all token/position pairs an and then aggregates
    as above
  - Separate num segments for topic and positional hash (can be zero to omit)
  - Replace normalizer and tokenizer with modeler, which takes a sentence and
    returns a bitmap as per the above process
  - Performance

- Encoder creation
  - Direcly uses bitmaps created in sentence loading step
  - Position dimensions/buckets approach potentially revised

- Classifier creation
  - Direcly uses bitmaps created in sentence loading step
  - Accepts two sentence bitmaps concatenated and predicts the label

# Later

- Pre-trained encoders: SNLI & MutiNLI datasets with various settings shared as
  sqlite.db files with training data pruned

- FAISS

- Update README

- Improve performance of loading glove embeddings. Write in C? Parallelize?
- Use GloVe or FastText directly on sentence datasets first
- Instead of strictly using sentence dataset words, include nearest N words to
  each word

- Move various inner loops to C (see cluster.lua TODOs)
- Fuzzy c-means clustering

# Eventually

- Finetuning helpers
- Explore weighted minhash, general feature hashing
