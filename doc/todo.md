# Now

- Use blas for computations and sqlite for offloading to disk
- Produce clusters for bitmap sizes 2^7-13

- Library
    - Load model as bitmaps
    - Sentence similarity (option to get bitmaps or cluster IDs separate from
      loading the model into memory, for use with sqlite, etc)

# Next

- Tsetlin Machine refinement of sentence representations

- Potential bugs in tsetlin.md
  - Ensure that when no literals are included, the clause evaluates to 1
  - Hyper-parameter T(hreshold)

# Later

- Fuzzy c-means clustering

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
        - sets the probability a word will have a cluster bit flipped,
          proportional to it's membership score
        - see ideas.md
    - membership_cutoff
        - default 0
        - if a fuzzy membership is less than this amount, it is ignored

- Efficient C for bitmaps (AVX on x86, Accelerate on Apple Silicon)

# Eventually

- See ideas.md

- Tsetlin Machine advancements
  - Drop clause (increases accuracy and learning speed)
  - Indexed (improves learning and classification speed)
  - Weighted (reduces memory footprint)
  - Multi-granular (eliminates hyper-parameter S(ensitivity))
  - Coalesced (reduces memory footprint for multi-output configurations)
