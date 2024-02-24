# Now

- Bitmap representation with roaring bitmaps

- Move santoku/matrix to separate lib
- Move santoku/bitmap to separate lib

- Migrate write distances file logic to separate commands: export-distances
- Migrate generate bitmaps file logic to separate commands: generate-bitmaps
- Migrate load words logic to separate command: load-glove-model
- Migrate cluster logic to separate command: cluster-words

- Command to ingest text files to sqlite, tag is file name by default
- Command to merge sqlite databases

- Support batching of max N words in memory
- Support incremental runs (picking up where you left off)

- Produce clusters for Glove 6B/42B 300D
    - 6B   50D   128   x
    - 6B   300D  128   x
    - 6B   300D  256   todo
    - 6B   300D  512   x
    - 6B   300D  1024  todo
    - 6B   300D  2048  todo
    - 6B   300D  4096  todo
    - 6B   300D  8192  todo
    - 42B  300D  128   todo
    - 42B  300D  256   todo
    - 42B  300D  512   todo
    - 42B  300D  1024  todo
    - 42B  300D  2048  todo
    - 42B  300D  8192  todo

- Host processed files on S3

- Bitmaps supporting multiple clusters
    - membership_min
        - default 1
        - minimum number of bits that should be flipped for a word, bypassing
          membership_threshold
        - 0 means word will be ignored if it doesn't have any cluster membership
          greater than membership_threshold
    - membership_max
        - default infinite
        - max number of bits that can be flipped for a word
    - membership_threshold
        - if a fuzzy membership is greater than this amount, the bit is always
          flipped
    - membership_probability
        - if set, membership_threshold is ignored
        - sets the probability a word will have additional cluster bits flipped,
          proportional to its distance the clusters in question
        - see ideas.md
    - membership_cutoff
        - default 0
        - if a fuzzy membership is less than this amount, it is ignored

- Library
    - Switch to croaring bitmaps
    - Load model as bitmaps
    - Sentence similarity (option to get bitmaps or cluster IDs separate from
      loading the model into memory, for use with sqlite, etc)

- Benchmark basic AND jaccard similarity

# Next

- Tsetlin Machine refinement of sentence representations

- Potential bugs in tsetlin.md
  - Ensure that when no literals are included, the clause evaluates to 1
  - Hyper-parameter T(hreshold)

# Later

- Move various inner loops to C (see cluster.lua TODOs)
- Multi-processing
- Fuzzy c-means clustering, update multi-cluster bitmap logic accordingly

- Benchmarks
  - TF-IDF standard
  - TF-IDF (translate words to clusters)
  - TF-IDF (translate words to multiple clusters)
  - Average of word embeddings
  - Bitmap Jaccard (single bit)
  - Bitmap Jaccard (multi-bit randomized)
  - Bitmap Jaccard (Tsetlin optimized)

# Eventually

- See ideas.md

- Tsetlin Machine advancements
  - Multi-class
  - Drop clause (increases accuracy and learning speed)
  - Indexed (improves learning and classification speed)
  - Weighted (reduces memory footprint)
  - Multi-granular (eliminates hyper-parameter S(ensitivity))
  - Coalesced (reduces memory footprint for multi-output configurations)

- Finetuning to a specific domain
