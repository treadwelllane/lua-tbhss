# Command Line Interface

## Loading Word Embeddings

Loads a GloVe text file into the database for use in clustering, conversion to
bitmaps, etc.

    tbhss load embeddings
      --cache cache.db
      --name glove2500
      --file glove-2500.txt

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

## Converting Word Embeddings to Encoded Word Bitmaps

A Siamese Tsetlin Machine model is used to convert word embeddings into bitmaps
such that the jaccard similarity of bitmaps approximates the cosine similarity
of the original word embeddings.

### Training the Word Embedding Encoder

    tbhss create encoder
      --cache cache.db
      --name glove2500
      --embeddings glove2500
      --bits 1024
      --max-records 10000
      --threshold-levels 20
      --train-test-ratio 0.1
      --clauses 40
      --state-bits 8
      --threshold 80
      --specificity 3
      --update-probability 2
      --drop-clause 0.75
      --boost-true-positive false
      --evaluate-every 5
      --epochs 250

### Creating Encoded Word Bitmaps

    tbhss create bitmaps encoded
      --cache cache.db
      --name glove2500
      --encoder glove2500

## Augmenting Document Bitmaps with Context

The representation of documents as an OR over word bitmaps can be improved by
integrating word position information. These transformed bitmaps are then
unioned to form a document-level bitmap that will be fed to an secondary Siamese
Tsetlin Machine model that uses this information to learn contextual
information, producing a contextualized bitmap representation that can also be
compared with others using jaccard similarity.

Note that the word bitmaps used can be computed via either the inference or the
cluster-based approach defined above.

### Loading a Sentence Similarity Dataset

    tbhss load sts
      --cache cache.db
      --name glove2500
      --file sts-benchmark.txt

### Training the Model (using encoder or cluster-based bitmaps)

    tbhss create contextualizer
      --cache cache.db
      [ --name glove2500.encoded | --name glove2500.clustered ]
      --sts glove2500
      [ --encoder glove2500 | --clusters glove2500 ]
      --bits 1024
      --waves 32
      --wave-period 10000
      --train-test-ratio 0.1
      --clauses 40
      --state-bits 8
      --threshold 80
      --specificity 3
      --update-probability 2
      --drop-clause 0.75
      --boost-true-positive false
      --evaluate-every 5
      --epochs 250

# Lua Interface

## Augmenting TF-IDF with Semantic Normalization

Given a clustered set of GloVe embeddings, replace words in a document with
their cluster IDs. When used with a TF-IDF based model, this adds a level of
word-based semantic normalization.

    local sts = require("santoku.sts")
    local model = sts.load_model("./cache.db")
    local clusters = model.load_clusters("glove2500")

    local str0 = "the quick brown fox jumped over the lazy dog"

    local str1 = clusters.gsub(str0, 1, 10, 1)
    assert(str1 == "$43 $9 $3 $21 $10 $65 $33 $24 $65")

    local str2 = clusters.gsub(str0, 1, 10, 0.8)
    assert(str2 == "$43 ...etc, each word converted to multiple cluster IDs")

The last arguments correspond to `min-set`, `max-set`, and `min-similarity` from
the section on converting embeddings to bitmaps using clusters above.

In the case of SQLite, this can be used to pre-process text for use with the
FTS5 extension, augmenting full-text search with semantic concepts.

## Encoding Documents to Bitmaps

Documents can be encoded to bitmaps with or without context.

Documents without context are represented as a bitmap created by taking the
union of the set of word bitmaps corresponding to the set of words in the
document. This effectively represents a document as a set of topics. The word
bitmaps used can be either clustered word bitmaps or encoded word bitmaps.

Documents with context are created by

### Clustered Bitmaps

    local sts = require("santoku.sts")
    local model = sts.load_model("./cache.db")

    local str = "the quick brown fox jumped over the lazy dog"

    local bitmapper = model.bitmapper("clustered", "glove2500")
    local bitmap = bitmapper(str)

### Encoded Bitmaps

Convert a document to a bitmap by taking the union of the set of word bitmaps
corresponding to the set of words in the document. This effectively represents a
document as a set of topics.

    local sts = require("santoku.sts")
    local model = sts.load_model("./cache.db")

    local str = "the quick brown fox jumped over the lazy dog"

    local bitmapper = model.bitmapper("encoded", "glove2500")
    local bitmap = bitmapper(str)

### Contextualized Clustered Bitmaps

    local sts = require("santoku.sts")
    local model = sts.load_model("./cache.db")

    local str = "the quick brown fox jumped over the lazy dog"

    local bitmapper = model.bitmapper("contextualized", "glove2500.clustered")
    local bitmap = bitmapper(str)

### Contextualized Encoded Bitmaps

    local sts = require("santoku.sts")
    local model = sts.load_model("./cache.db")

    local str = "the quick brown fox jumped over the lazy dog"

    local bitmapper = model.bitmapper("contextualized", "glove2500.encoded")
    local bitmap = bitmapper(str)

## Creating & Persisting a FAISS Index

Note that the settings for the FAISS index created are pre-selected to support
bitmaps and the jaccard similarity metric.

    local sts = require("santoku.sts")
    local index = sts.create_index_flat(1024)

    local bitmaps = { ... }

    for i = 1, #bitmaps do
        index.add(i, bitmaps[i])
    end

    index.persist("./index.faiss")

### Customizing FAISS

    local sts = require("santoku.sts")
    local index0 = sts.create_index_ivf(1024, ...TODO)
    local index1 = sts.create_index_hnsw(1024, ...TODO)

## Loading a FAISS index from disk

    local sts = require("santoku.sts")
    local index = sts.load_index("./index.faiss")
    ...

## Deleting from a FAISS index

    local sts = require("santoku.sts")
    local index = sts.load_index("./index.faiss")
    index.delete(10)
    index.persist("./index.faiss")

# Appendix

## Computing Position Bitmaps for Contextualized Bitmaps

Position bitmaps are represented using sinusoidal encodings, where the index of
a word is mapped to a set of sin and cosine values that are subsequently
binarized via thresholding.

    w: the number of sinusoidal values used store positional information
    wp: the sinusoidal wave period, by default 10000

    t: the number of threshold levels for wave binarization, calculated by
    dividing the number of output bits by w

    thr: a function that converts a floating point value into a set of bits by
    dividing the [-1, 1] range into t levels and setting the single correponding
    bit.

    Note: w * t must equal the number of bits in the sentence bitmap.

    b: the initially length-0 position bitmap

    For each word in the source document
      p = the position of the word in the source document
      For i = 0, i < d / 2, i ++
        b0 = thr(t, sin(p / wp ^ (2 * i / w)))
        b1 = thr(t, cos(p / wp ^ (2 * i / w)))
        Concatenate b with b0 and b1
      b is now the position bitmap for this word in the source document

## Integrating Word Position Bitmaps with Word Bitmaps

    integrated-bitmap = word-bitmap CONCAT (position-bitmap AND word-bitmap)

## TODOs

- Explore whether hamming distance makes more sense than jaccard similarity in
  the second stage (augmenting document bitmaps with context). It does not make
  sense for the first stage, since documents are represented as sets of topics.

- Document support for FAISS index configuration for disk overflow, and
  non-exhaustive algorithms like HNSW, inverted file, etc.
