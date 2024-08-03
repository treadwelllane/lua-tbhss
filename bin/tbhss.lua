-- luacheck: no max line length

local argparse = require("argparse")
local serialize = require("santoku.serialize") -- luacheck: ignore

local init_db = require("tbhss.db")
local words = require("tbhss.words")
local sentences = require("tbhss.sentences")
local clusters = require("tbhss.clusters")
local encoder = require("tbhss.encoder")
local search = require("tbhss.search")

local fun = require("santoku.functional")
local op = require("santoku.op")

local parser = argparse()
  :name("tbhss")
  :description("semantic sentence encodings")

parser:command_target("cmd")

local function base_flags (cmd)
  cmd:option("--cache", "cache db file", nil, nil, 1, 1)
end

local cmd_load = parser:command("load", "load data into the cache")
cmd_load:command_target("cmd_load")

local cmd_load_words = cmd_load:command("words", "load words")
base_flags(cmd_load_words)
cmd_load_words:option("--name", "name of loaded words", nil, nil, 1, 1)
cmd_load_words:option("--file", "path to input words file", nil, nil, 1, 1)

local cmd_load_train_sentences = cmd_load:command("train-sentences", "load NLI dataset")
base_flags(cmd_load_train_sentences)
cmd_load_train_sentences:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_train_sentences:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
cmd_load_train_sentences:option("--clusters", "name of word clusters, num, min-set, max-set, min-similarity, include-raw", nil, nil, 6, "0-1")
cmd_load_train_sentences:option("--segments", "number of segments for positions", nil, tonumber, 1, 1)
cmd_load_train_sentences:option("--dimensions", "number of dimensions for positions", nil, tonumber, 1, 1)
cmd_load_train_sentences:option("--buckets", "number of buckets for positions", nil, tonumber, 1, 1)
cmd_load_train_sentences:option("--saturation", "BM25 saturation", 1.2, tonumber, 1, 1)
cmd_load_train_sentences:option("--length-normalization", "BM25 length normalization", 0.75, tonumber, 1, 1)
cmd_load_train_sentences:option("--max-records", "Max number of sentences to load", nil, tonumber, 1, "0-1")
cmd_load_train_sentences:option("--jobs", "", nil, tonumber, 1, "0-1")

local cmd_load_test_sentences = cmd_load:command("test-sentences", "load NLI dataset")
base_flags(cmd_load_test_sentences)
cmd_load_test_sentences:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_test_sentences:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
cmd_load_test_sentences:option("--clusters", "name of word clusters, num, min-set, max-set, min-similarity, include-raw", nil, nil, 6, "0-1")
cmd_load_test_sentences:option("--max-records", "Max number of sentences to load", nil, tonumber, 1, "0-1")
cmd_load_test_sentences:option("--model", "train model to use for fingerprinting", nil, nil, 1, 1)

local cmd_create = parser:command("create")
cmd_create:command_target("cmd_create")

local cmd_create_clusters = cmd_create:command("clusters", "create clusters")
base_flags(cmd_create_clusters)
cmd_create_clusters:option("--name", "name of created clusters", nil, nil, 1, 1)
cmd_create_clusters:option("--words", "name of words to cluster", nil, nil, 1, 1)
cmd_create_clusters:option("--clusters", "number of clusters", nil, tonumber, 1, 1)
cmd_create_clusters:option("--filter-words", "snli dataset to filter words by", nil, nil, 1, "0-1")

local cmd_create_encoder = cmd_create:command("encoder", "create an encoder")
base_flags(cmd_create_encoder)
cmd_create_encoder:option("--name", "name of created encoder", nil, nil, 1, 1)
cmd_create_encoder:option("--sentences", "name of sentences model(s) to use", nil, nil, 2, 1)
cmd_create_encoder:option("--max-records", "Max number of train and test pairs", nil, tonumber, 2, "0-1")
cmd_create_encoder:option("--encoded-bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_encoder:option("--margin", "margin for triplet loss", nil, tonumber, 1, 1)
cmd_create_encoder:option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_encoder:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_encoder:option("--state-bits", "Tsetlin Machine state bits", nil, tonumber, 1, 1)
cmd_create_encoder:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_encoder:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 2, 1)
cmd_create_encoder:option("--active-clause", "Tsetlin Machine active clause", nil, tonumber, 1, 1)
cmd_create_encoder:option("--boost-true-positive", "Tsetlin Machine boost true positive", nil, fun.bind(op.eq, "true"), 1, 1):choices({ "true", "false" })
cmd_create_encoder:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, 1)
cmd_create_encoder:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local cmd_search = parser:command("search")
base_flags(cmd_search)

cmd_search:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_search:option("--train-file", "path to train NLI dataset file", nil, nil, 1, 1)
cmd_search:option("--test-file", "path to test NLI dataset file", nil, nil, 1, 1)

cmd_search:option("--clusters-number", "", { 64, 128, 256, 512, 1024, 2048 }, nil, "+", "0-1")
cmd_search:option("--clusters-min-set", "", { 1 }, nil, "+", "0-1")
cmd_search:option("--clusters-max-set", "", { 1, 2, 4, 8 }, nil, "+", "0-1")
cmd_search:option("--clusters-min-similarity", "", { 0, 0.25, 0.5, 0.75 }, nil, "+", "0-1")
cmd_search:option("--clusters-include-raw", "", { "true", "false" }, nil, "+", "0-1")
cmd_search:option("--segments", "", { 2, 4, 8 }, nil, "+", "0-1")
cmd_search:option("--dimensions", "", { 2, 4, 8, 16, 32, 64 }, nil, "+", "0-1")
cmd_search:option("--buckets", "", { 8, 16, 32, 64, 128, 256, 512 }, nil, "+", "0-1")
cmd_search:option("--saturation", "", { 1.2 }, nil, "+", "0-1")
cmd_search:option("--length-normalization", "", { 0.75 }, nil, "+", "0-1")

cmd_search:option("--encoded-bits", "", { 128, 256, 512, 1024, 2048, 4096, 8192 }, nil, 1, "0-1")
cmd_search:option("--margin", "", { 0.05, 0.1, 0.15, 0.2 }, nil, "+", "0-1")
cmd_search:option("--loss-alpha", "", { 0.25 }, nil, "+", "0-1")
cmd_search:option("--clauses", "", { 256, 512, 1024, 2048, 4096, 8192 }, nil, "+", "0-1")
cmd_search:option("--state-bits", "", { 8 }, nil, "+", "0-1")
cmd_search:option("--threshold", "", { 16, 32, 256, 512, 1024, 2048, 4096 }, nil, "+", "0-1")
cmd_search:option("--specificity-low", "", { 2, 10, 25, 50, 100, 150 }, nil, "+", "0-1")
cmd_search:option("--specificity-high", "", { 200, 150, 50, 25, 10, 2 }, nil, "+", "0-1")
cmd_search:option("--active-clause", "", { 0.85 }, nil, "+", "0-1")
cmd_search:option("--boost-true-positive", "", { "true", "false" }, nil, "+", "0-1")

cmd_search:option("--search", "", nil, nil, 1, 1):choices({ "grid", "random" })
cmd_search:option("--max-minutes", "", nil, tonumber, 1, "0-1")
cmd_search:option("--words", "", nil, nil, 1, 1)
cmd_search:option("--jobs", "", nil, nil, 1, "0-1")
cmd_search:option("--epochs", "", nil, nil, 1, 1)
cmd_search:option("--evaluate-every", "", 5, nil, 1, 1)

local args = parser:parse()

local db = init_db(args.cache)

if args.cmd == "load" and args.cmd_load == "words" then
  words.load_words(db, args)
elseif args.cmd == "load" and args.cmd_load == "train-sentences" then
  if args.clusters then
    args.clusters = {
      words = args.clusters[1],
      clusters = tonumber(args.clusters[2]),
      min_set = tonumber(args.clusters[3]),
      max_set = tonumber(args.clusters[4]),
      min_similarity = tonumber(args.clusters[5]),
      include_raw = args.clusters[6] == "true",
    }
  end
  sentences.load_train_sentences(db, args)
elseif args.cmd == "load" and args.cmd_load == "test-sentences" then
  sentences.load_test_sentences(db, args)
elseif args.cmd == "create" and args.cmd_create == "clusters" then
  clusters.create_clusters(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" then
  encoder.create_encoder(db, args)
elseif args.cmd == "search" then
  search.search_hyperparams(db, args)
else
  print(parser:get_usage())
  os.exit(1)
end
