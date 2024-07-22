-- luacheck: no max line length

local argparse = require("argparse")
local serialize = require("santoku.serialize") -- luacheck: ignore

local init_db = require("tbhss.db")
local words = require("tbhss.words")
local sentences = require("tbhss.sentences")
local clusters = require("tbhss.clusters")
local encoder = require("tbhss.encoder")

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

local cmd_load_sentences = cmd_load:command("sentences", "load NLI dataset")
base_flags(cmd_load_sentences)
cmd_load_sentences:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_sentences:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
cmd_load_sentences:option("--clusters", "name of word clusters, num, min-set, max-set, min-similarity, include-raw", nil, nil, 6, 1)
cmd_load_sentences:option("--topic-segments", "number of segments for topics", nil, tonumber, 1, 1)
cmd_load_sentences:option("--position-segments", "number of segments for positions", nil, tonumber, 1, 1)
cmd_load_sentences:option("--position-dimensions", "number of dimensions for positions", nil, tonumber, 1, 1)
cmd_load_sentences:option("--position-buckets", "number of buckets for positions", nil, tonumber, 1, 1)
cmd_load_sentences:option("--saturation", "BM25 saturation", 1.2, tonumber, 1, 1)
cmd_load_sentences:option("--length-normalization", "BM25 length normalization", 0.75, tonumber, 1, 1)
cmd_load_sentences:option("--max-records", "Max number records to use in training", nil, tonumber, 1, "0-1")

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
cmd_create_encoder:option("--sentences", "name of sentences model(s) to use", nil, nil, "1-2", 1)
cmd_create_encoder:option("--encoded-bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_encoder:option("--margin", "margin for triplet loss", nil, tonumber, 1, 1)
cmd_create_encoder:option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_encoder:option("--train-test-ratio", "ratio of train to test examples", nil, tonumber, 1, 1)
cmd_create_encoder:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_encoder:option("--state-bits", "Tsetlin Machine state bits", nil, tonumber, 1, 1)
cmd_create_encoder:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_encoder:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 2, 1)
cmd_create_encoder:option("--active-clause", "Tsetlin Machine active clause", nil, tonumber, 1, 1)
cmd_create_encoder:option("--boost-true-positive", "Tsetlin Machine boost true positive", nil, fun.bind(op.eq, "true"), 1, 1):choices({ "true", "false" })
cmd_create_encoder:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, "0-1")
cmd_create_encoder:option("--max-records", "Max number records to use in training", nil, tonumber, 1, "0-1")
cmd_create_encoder:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local args = parser:parse()

local db = init_db(args.cache)

if args.cmd == "load" and args.cmd_load == "words" then
  words.load_words(db, args)
elseif args.cmd == "load" and args.cmd_load == "sentences" then
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
  sentences.load_sentences(db, args)
elseif args.cmd == "create" and args.cmd_create == "clusters" then
  clusters.create_clusters(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" then
  encoder.create_encoder(db, args)
else
  print(parser:get_usage())
  os.exit(1)
end
