# Command Line Interface

## Loading Word Embeddings

Loads a GloVe text file into the database for use in clustering, conversion to
bitmaps, etc.

    tbhss load embeddings
      --cache cache.db
      --name glove2500
      --file glove-2500.txt

### Loading a NLI dataset

    tbhss load sentences
      --cache cache.db
      --name snli-dev
      --file snli_1.0_dev.txt

## Clustering Word Embeddings

Apply K-means clustering to assign words to clusters.

    tbhss create clusters
      --cache cache.db
      --name glove2500
      --embeddings glove2500
      --clusters 256

## Converting Word Embeddings to Clustered Word Bitmaps

Word bitmaps are created by setting bits in an initially empty bitmap accorrding
to the word's distance from a cluster. In this example, the bit corresponding to
the clusters with similarity scores greater than 0.8 are set to 1.

    tbhss create bitmaps clustered
      --cache cache.db
      --name glove2500
      --clusters glove2500
      --min-similarity 0.8
      --min-set 1
      --max-set 10

## Encoding Sentences

A recurrent siamese Tsetlin Machine model is used to convert text into bitmaps
such that the jaccard similarity of bitmaps approximates the semantic similarity
of the text.

### Training the Encoder

    tbhss create encoder
      --cache cache.db
      --name glove2500
      --bitmaps glove2500
      --sentences snli-dev
      --output-bits 1024
      --margin 0.1
      --scale-loss 0.5
      --train-test-ratio 0.1
      --clauses 40
      --state-bits 8
      --threshold 80
      --specificity 3
      --update-probability 0.75
      --drop-clause 0.75
      --boost-true-positive false
      --evaluate-every 5
      --max-records 1000
      --epochs 250

# Lua Interface

## Augmenting TF-IDF with Semantic Normalization

Given a clustered set of GloVe embeddings, replace words in a document with
their cluster IDs. When used with a TF-IDF based model, this adds a level of
word-based semantic normalization.

    local tbhss = require("tbhss")
    local normalizer = tbhss.normalizer("./cache.db", "glove")

    local str0 = "the quick brown fox jumped over the lazy dog"

    local str1 = normalizer.normalize(str0, 1, 1, 0)
    assert(str1 == "$43 $9 $3 $21 $10 $65 $33 $24 $65")

    local str2 = normalizer.normalize(str0, 1, 10, 0.8)
    assert(str2 == "$43 ...etc, each word converted to multiple cluster IDs")

The last arguments correspond to `min-set`, `max-set`, and `min-similarity` from
the section on converting embeddings to bitmaps using clusters above.

In the case of SQLite, this can be used to pre-process text for use with the
FTS5 extension, augmenting full-text search with semantic concepts.

## Encoding Sentences

    local tbhss = require("tbhss")
    local encoder = tbhss.encoder("./cache.db", "glove")
    local str = "the quick brown fox jumped over the lazy dog"
    local bitmap = encoder.encode(str)

## Creating & Persisting a FAISS Index

Note that the settings for the FAISS index created are pre-selected to support
bitmaps and the jaccard similarity metric.

    local tbhss = require("tbhss")
    local index = tbhss.create_index_flat(1024)

    local bitmaps = { ... }

    for i = 1, #bitmaps do
        index.add(i, bitmaps[i])
    end

    index.persist("./index.faiss")

### Customizing FAISS

    local tbhss = require("tbhss")
    local index0 = tbhss.create_index_ivf(1024, ...TODO)
    local index1 = tbhss.create_index_hnsw(1024, ...TODO)

## Loading a FAISS index from disk

    local tbhss = require("tbhss")
    local index = tbhss.load_index("./index.faiss")
    ...

## Deleting from a FAISS index

    local tbhss = require("tbhss")
    local index = tbhss.load_index("./index.faiss")
    index.delete(10)
    index.persist("./index.faiss")

# Appendix

## TODOs

- Document support for FAISS index configuration for disk overflow, and
  non-exhaustive algorithms like HNSW, inverted file, etc.
