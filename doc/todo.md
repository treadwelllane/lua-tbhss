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
  x Bitmaps are created using tokens arrays and fts5vocab
    x For each sentence, get bm25 weights for each term
    x The first half of the bitmap hashes the set of tokens and aggregates using
      the bm25 weights
    x The second half of bitmap hashes token/position pairs sinusoidally and
      also aggregates using the bm25 weights
    x Aggregate by weight
  x Replace normalizer and tokenizer with modeler, which takes a sentence and
    returns a bitmap as per the above process
  x Update test/tbhss/hash to test the modeler:
    x Similar sentences should have smaller hamming distances
  - Improve performance of expanding tokens and creating fingerprints

- Encoder creation
  - Uses fingerprints from sentence loading step

- Classifier creation
  - Given two sentence fingerprints concatenated, predit entailment, neutral, or
    contradiction

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

# Consider

- Removing position segments flag and just use position dimensions flag
- Flag for weight of token without score in modeler (currently ignores)

# Eventually

- Finetuning helpers
- Explore weighted minhash, general feature hashing
