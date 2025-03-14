-- luacheck: no max line length

local argparse = require("argparse")
local serialize = require("santoku.serialize") -- luacheck: ignore
local str = require("santoku.string")

local init_db = require("tbhss.db")
local words = require("tbhss.words")
local modeler = require("tbhss.modeler")
local clusters = require("tbhss.clusters")
local encoder = require("tbhss.encoder")
local autoencoder = require("tbhss.autoencoder")
local classifier = require("tbhss.classifier")
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

local cmd_process_snli_pairs = cmd_process:command("snli-pairs", "pre-process NLI datasets into pairs")
cmd_process_snli_pairs:option("--inputs", "Stanford NLI formatted input files", nil, nil, "+", 1)
cmd_process_snli_pairs:option("--train-test-ratio", "ratio of train to test pairs", nil, tonumber, 1, 1)
cmd_process_snli_pairs:option("--output-train", "file to write train pairs to", nil, nil, 1, 1)
cmd_process_snli_pairs:option("--output-test", "file to write test pairs to", nil, nil, 1, 1)

local cmd_process_snli_triplets = cmd_process:command("snli-triplets", "pre-process NLI datasets into triplets")
cmd_process_snli_triplets:option("--inputs", "Stanford NLI formatted input files", nil, nil, "+", 1)
cmd_process_snli_triplets:option("--train-test-ratio", "ratio of train to test triplets", nil, tonumber, 1, 1)
cmd_process_snli_triplets:option("--output-train", "file to write train triplets to", nil, nil, 1, 1)
cmd_process_snli_triplets:option("--output-test", "file to write test triplets to", nil, nil, 1, 1)

local cmd_load = parser:command("load", "load data into the cache")
cmd_load:command_target("cmd_load")

local cmd_load_words = cmd_load:command("words", "load words")
base_flags(cmd_load_words)
cmd_load_words:option("--name", "name of loaded words", nil, nil, 1, 1)
cmd_load_words:option("--file", "path to input words file", nil, nil, 1, 1)

local cmd_load_train_pairs = cmd_load:command("train-pairs", "load NLI dataset")
base_flags(cmd_load_train_pairs)
cmd_load_train_pairs:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_train_pairs:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
local cmd_load_train_pairs_tokenizer = cmd_load_train_pairs:option("--tokenizer", "name of tokenization algorithm, algorithm args...", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", "0-1")
cmd_load_train_pairs:mutex(
  cmd_load_train_pairs_tokenizer,
  cmd_load_train_pairs:option("--clusters", "name of clustering algorithm, algorithm args...", nil, function (v)
    return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
  end, "+", "0-1"))
cmd_load_train_pairs:mutex(
  cmd_load_train_pairs_tokenizer,
  cmd_load_train_pairs:option("--include-pos", "", nil, nil, 0, "0-1"))
cmd_load_train_pairs:mutex(
  cmd_load_train_pairs_tokenizer,
  cmd_load_train_pairs:option("--pos-ancestors", "", nil, tonumber, 1, "0-1"))
cmd_load_train_pairs:mutex(
  cmd_load_train_pairs_tokenizer,
  cmd_load_train_pairs:option("--dedupe-pos", "", nil, nil, 0, "0-1"))
cmd_load_train_pairs:option("--fingerprints", "name of fingerprinting algorithm, algorithm args...", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", 1)
cmd_load_train_pairs:option("--weighting", "name of weighting algorithm, algorithm args...", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", "0-1")
cmd_load_train_pairs:option("--max-records", "Max number of pairs to load", nil, tonumber, 1, "0-1")
cmd_load_train_pairs:option("--jobs", "", nil, tonumber, 1, "0-1")

local cmd_load_test_pairs = cmd_load:command("test-pairs", "load NLI dataset")
base_flags(cmd_load_test_pairs)
cmd_load_test_pairs:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_test_pairs:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
cmd_load_test_pairs:option("--max-records", "Max number of pairs to load", nil, tonumber, 1, "0-1")
cmd_load_test_pairs:option("--model", "train model to use for fingerprinting", nil, nil, 1, 1)

local cmd_load_train_triplets = cmd_load:command("train-triplets", "load NLI dataset")
base_flags(cmd_load_train_triplets)
cmd_load_train_triplets:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_train_triplets:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
local cmd_load_train_triplets_tokenizer = cmd_load_train_triplets:option("--tokenizer", "name of tokenization algorithm, algorithm args...", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", "0-1")
cmd_load_train_triplets:mutex(
  cmd_load_train_triplets_tokenizer,
  cmd_load_train_triplets:option("--clusters", "name of clustering algorithm, algorithm args...", nil, function (v)
    return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
  end, "+", "0-1"))
cmd_load_train_triplets:mutex(
  cmd_load_train_triplets_tokenizer,
  cmd_load_train_triplets:option("--include-pos", "", nil, nil, 0, "0-1"))
cmd_load_train_triplets:mutex(
  cmd_load_train_triplets_tokenizer,
  cmd_load_train_triplets:option("--pos-ancestors", "", nil, tonumber, 1, "0-1"))
cmd_load_train_triplets:mutex(
  cmd_load_train_triplets_tokenizer,
  cmd_load_train_triplets:option("--dedupe-pos", "", nil, nil, 0, "0-1"))
cmd_load_train_triplets:option("--fingerprints", "name of fingerprinting algorithm, algorithm args...", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", 1)
cmd_load_train_triplets:option("--weighting", "name of weighting algorithm, algorithm args...", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", "0-1")
cmd_load_train_triplets:option("--max-records", "Max number of triplets to load", nil, tonumber, 1, "0-1")
cmd_load_train_triplets:option("--jobs", "", nil, tonumber, 1, "0-1")

local cmd_load_test_triplets = cmd_load:command("test-triplets", "load NLI dataset")
base_flags(cmd_load_test_triplets)
cmd_load_test_triplets:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_test_triplets:option("--file", "path to NLI dataset file", nil, nil, 1, 1)
cmd_load_test_triplets:option("--max-records", "Max number of triplets to load", nil, tonumber, 1, "0-1")
cmd_load_test_triplets:option("--model", "train model to use for fingerprinting", nil, nil, 1, 1)

local cmd_load_compressed_triplets = cmd_load:command("compressed-triplets", "compress a triplets model using an autoencoder")
base_flags(cmd_load_compressed_triplets)
cmd_load_compressed_triplets:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_compressed_triplets:option("--triplets", "name of triplets model to compress", nil, nil, 1, 1)
cmd_load_compressed_triplets:option("--autoencoder", "name of autoencoder to use", nil, nil, 1, 1)
cmd_load_compressed_triplets:option("--max-records", "Max number of triplets to load", nil, tonumber, 1, "0-1")

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

local cmd_create_autoencoder = cmd_create:command("autoencoder", "create an autoencoder")
base_flags(cmd_create_autoencoder)
cmd_create_autoencoder:option("--name", "name of created autoencoder", nil, nil, 1, 1)
cmd_create_autoencoder:option("--triplets", "name of triplets model(s) to use", nil, nil, 2, 1)
cmd_create_autoencoder:option("--max-records", "Max number of train and test pairs", nil, tonumber, 2, "0-1")
cmd_create_autoencoder:option("--encoded-bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_autoencoder:option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_autoencoder:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_autoencoder:option("--state-bits", "Tsetlin Machine state bits", nil, tonumber, 1, 1)
cmd_create_autoencoder:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_autoencoder:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 2, 1)
cmd_create_autoencoder:option("--active-clause", "Tsetlin Machine active clause", nil, tonumber, 1, 1)
cmd_create_autoencoder:option("--boost-true-positive", "Tsetlin Machine boost true positive", nil, fun.bind(op.eq, "true"), 1, 1):choices({ "true", "false" })
cmd_create_autoencoder:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, 1)
cmd_create_autoencoder:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local cmd_create_classifier = cmd_create:command("classifier", "create a classifier")
base_flags(cmd_create_classifier)
cmd_create_classifier:option("--name", "name of created classifier", nil, nil, 1, 1)
cmd_create_classifier:option("--pairs", "name of triplets/pairs model(s) to use", nil, nil, 2, 1)
cmd_create_classifier:option("--max-records", "Max number of train and test pairs", nil, tonumber, 2, "0-1")
cmd_create_classifier:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_classifier:option("--state-bits", "Tsetlin Machine state bits", nil, tonumber, 1, 1)
cmd_create_classifier:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_classifier:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 2, 1)
cmd_create_classifier:option("--active-clause", "Tsetlin Machine active clause", nil, tonumber, 1, 1)
cmd_create_classifier:option("--boost-true-positive", "Tsetlin Machine boost true positive", nil, fun.bind(op.eq, "true"), 1, 1):choices({ "true", "false" })
cmd_create_classifier:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, 1)
cmd_create_classifier:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local args = parser:parse()

if args.cmd == "process" and args.cmd_process == "snli-triplets" then
  preprocess.snli_triplets(args)
  return
elseif args.cmd == "process" and args.cmd_process == "snli-pairs" then
  preprocess.snli_pairs(args)
  return
end

local db = init_db(args.cache)

if args.cmd == "load" and args.cmd_load == "words" then
  words.load_words(db, args)
elseif args.cmd == "load" and args.cmd_load == "train-pairs" then
  modeler.load_train_pairs(db, args)
elseif args.cmd == "load" and args.cmd_load == "test-pairs" then
  modeler.load_test_pairs(db, args)
elseif args.cmd == "load" and args.cmd_load == "train-triplets" then
  modeler.load_train_triplets(db, args)
elseif args.cmd == "load" and args.cmd_load == "test-triplets" then
  modeler.load_test_triplets(db, args)
elseif args.cmd == "load" and args.cmd_load == "compressed-triplets" then
  modeler.load_compressed_triplets(db, args)
elseif args.cmd == "create" and args.cmd_create == "clusters" then
  clusters.create_clusters(db, args)
elseif args.cmd == "create" and args.cmd_create == "autoencoder" then
  autoencoder.create_autoencoder(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" then
  encoder.create_encoder(db, args)
elseif args.cmd == "create" and args.cmd_create == "classifier" then
  classifier.create_classifier(db, args)
else
  print(parser:get_usage())
  os.exit(1)
end
