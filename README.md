# Command Line Interface

## Loading Word Embeddings

Loads a GloVe text file into the database for use in clustering, conversion to
bitmaps, etc.

    tbhss load words
      --cache cache.db
      --name glove2500
      --file glove-2500.txt

### Loading a NLI dataset

Loads sentences and labels from an NLI dataset file, modeling the sentences as
bitmaps. Sentences are modeled as a concatenation of two bm25-weighted simhash
fingerprints. The first fingerprint is created using the words from the
sentences along with their most associated word clusters. The second fingerprint
is created with the words and clusters hashed with their positions in the
sentence using a sinusoidal positional encoding.

    tbhss load sentences
      --cache cache.db
      --name snli-dev
      --file snli_1.0_dev.txt
      --clusters glove2500 128 1 3 0.5 true
      --topic-segments 4
      --position-segments 1
      --position-dimensions 4
      --position-buckets 20
      --saturation 1.2
      --length-normalization 0.75

## Clustering Word Embeddings

Apply K-means clustering to assign words to clusters.

    tbhss create clusters
      --cache cache.db
      --name glove2500
      --words glove2500
      --clusters 256
      --filter-words snli-dev

## Encoding Sentences

TODO

## Predicting Sentence Entailment

TODO

# Lua Interface

## Augmenting TF-IDF with Semantic Normalization

Given a clustered set of GloVe embeddings, replace words in a document with
their cluster IDs. When used with a TF-IDF based model, this adds a level of
word-based semantic normalization.

    local tbhss = require("tbhss")
    local modeler = tbhss.modeler("./cache.db", "snli-dev")

    local str0 = "the quick brown fox jumped over the lazy dog"

    local str1 = table.concat(modeler.model(str0, true), " ")
    assert(str1 == "43 -12 9 -4 3 -1 21 -23 10 -5 65 -9 33 -43 24 -22 65 -1")

In the case of SQLite, this can be used to pre-process text for use with the
FTS5 extension, augmenting full-text search with semantic concepts.

## Encoding Sentences

    local tbhss = require("tbhss")
    local encoder = tbhss.encoder("./cache.db", "snli-dev")
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
