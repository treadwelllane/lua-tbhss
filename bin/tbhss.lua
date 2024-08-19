-- luacheck: no max line length

local argparse = require("argparse")
local serialize = require("santoku.serialize") -- luacheck: ignore
local str = require("santoku.string")
local arr = require("santoku.array")

local init_db = require("tbhss.db")
local words = require("tbhss.words")
local modeler = require("tbhss.modeler")
local clusters = require("tbhss.clusters")
local encoder = require("tbhss.encoder")
local preprocess = require("tbhss.preprocess")

local fun = require("santoku.functional")
local op = require("santoku.op")

local parser = argparse()
  :name("tbhss")
  :description("semantic sentence encodings")

parser:command_target("cmd")

local function base_flags (cmd)
  cmd:option("--cache", "cache db file", nil, nil, 1, 1)
end

local cmd_process = parser:command("process", "pre-process data files")
cmd_process:command_target("cmd_process")

local cmd_process_snli = cmd_process:command("snli", "pre-process NLI datasets into triplets")
cmd_process_snli:option("--inputs", "Stanford NLI formatted input files", nil, nil, "+", 1)
cmd_process_snli:option("--train-test-ratio", "ratio of train to test triplets", nil, tonumber, 1, 1)
cmd_process_snli:option("--output-train", "file to write train triplets to", nil, nil, 1, 1)
cmd_process_snli:option("--output-test", "file to write test triplets to", nil, nil, 1, 1)

local cmd_load = parser:command("load", "load data into the cache")
cmd_load:command_target("cmd_load")

local cmd_load_words = cmd_load:command("words", "load words")
base_flags(cmd_load_words)
cmd_load_words:option("--name", "name of loaded words", nil, nil, 1, 1)
cmd_load_words:option("--file", "path to input words file", nil, nil, 1, 1)

local cmd_load_train_triplets = cmd_load:command("train-triplets", "load NLI dataset")
base_flags(cmd_load_train_triplets)
cmd_load_train_triplets:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_train_triplets:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
cmd_load_train_triplets:option("--clusters", "name of word clusters, algorithm, algorithm args...", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", "0-1")
cmd_load_train_triplets:option("--dimensions", "number of dimensions for positions", nil, tonumber, 1, 1)
cmd_load_train_triplets:option("--saturation", "BM25 saturation", 1.2, tonumber, 1, 1)
cmd_load_train_triplets:option("--length-normalization", "BM25 length normalization", 0.75, tonumber, 1, 1)
cmd_load_train_triplets:option("--max-records", "Max number of triplets to load", nil, tonumber, 1, "0-1")
cmd_load_train_triplets:option("--jobs", "", nil, tonumber, 1, "0-1")

local cmd_load_test_triplets = cmd_load:command("test-triplets", "load NLI dataset")
base_flags(cmd_load_test_triplets)
cmd_load_test_triplets:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_test_triplets:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
cmd_load_test_triplets:option("--clusters", "name of word clusters, num, min-set, max-set, min-similarity, include-raw", nil, nil, 6, "0-1")
cmd_load_test_triplets:option("--max-records", "Max number of triplets to load", nil, tonumber, 1, "0-1")
cmd_load_test_triplets:option("--model", "train model to use for fingerprinting", nil, nil, 1, 1)

local cmd_create = parser:command("create")
cmd_create:command_target("cmd_create")

local cmd_create_clusters = cmd_create:command("clusters", "create clusters")
base_flags(cmd_create_clusters)
cmd_create_clusters:option("--name", "name of created clusters", nil, nil, 1, 1)
cmd_create_clusters:option("--words", "name of words to cluster", nil, nil, 1, 1)
cmd_create_clusters:option("--filter-words", "snli dataset to filter words by", nil, nil, 1, "0-1")
cmd_create_clusters:option("--algorithm", "clustering algorithm", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", 1)

local cmd_create_encoder = cmd_create:command("encoder", "create an encoder")
base_flags(cmd_create_encoder)
cmd_create_encoder:option("--name", "name of created encoder", nil, nil, 1, 1)
cmd_create_encoder:option("--triplets", "name of triplets model(s) to use", nil, nil, 2, 1)
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

local args = parser:parse()

if args.cmd == "process" and args.cmd_process == "snli" then
  preprocess.snli(args)
  return
end

local db = init_db(args.cache)

if args.cmd == "load" and args.cmd_load == "words" then
  words.load_words(db, args)
elseif args.cmd == "load" and args.cmd_load == "train-triplets" then
  if args.clusters then
    args.clusters = {
      words = args.clusters[1],
      algorithm = { arr.spread(args.clusters, 2) },
    }
  end
  modeler.load_train_triplets(db, args)
elseif args.cmd == "load" and args.cmd_load == "test-triplets" then
  modeler.load_test_triplets(db, args)
elseif args.cmd == "create" and args.cmd_create == "clusters" then
  clusters.create_clusters(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" then
  encoder.create_encoder(db, args)
else
  print(parser:get_usage())
  os.exit(1)
end
