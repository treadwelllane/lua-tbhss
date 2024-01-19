# Now

- Use sqlite for computations

- Library
    - Load model
    - Lookup of word cluster and bitmap
    - Sentence similarity

# Next

- Tsetlin Machine refinement of sentence representations

- Potential bugs in tsetlin.md
  - Ensure that when no literals are included, the clause evaluates to 1
  - Hyper-parameter T(hreshold)

# Later

- Allow a word to belong to N clusters with a max_membership and
  membership_threshold

- Allow randomization of additional cluster membership (see allowing for unique
  word representation in ideas.md)

- Efficient C for bitmaps (AVX on x86, Accelerate on Apple Silicon)

# Eventually

- See ideas.md

- Tsetlin Machine advancements
  - Drop clause (increases accuracy and learning speed)
  - Indexed (improves learning and classification speed)
  - Weighted (reduces memory footprint)
  - Multi-granular (eliminates hyper-parameter S(ensitivity))
  - Coalesced (reduces memory footprint for multi-output configurations)
