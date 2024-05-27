local argparse = require("argparse")
local serialize = require("santoku.serialize") -- luacheck: ignore

local init_db = require("tbhss.db")
local words = require("tbhss.words")
local sentences = require("tbhss.sentences")
local clusters = require("tbhss.clusters")
local bitmaps = require("tbhss.bitmaps")
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

local cmd_create = parser:command("create")
cmd_create:command_target("cmd_create")

local cmd_create_clusters = cmd_create:command("clusters", "create clusters")
base_flags(cmd_create_clusters)
cmd_create_clusters:option("--name", "name of created clusters", nil, nil, 1, 1)
cmd_create_clusters:option("--words", "name of words to cluster", nil, nil, 1, 1)
cmd_create_clusters:option("--clusters", "number of clusters", nil, tonumber, 1, 1)
cmd_create_clusters:option("--filter-words", "snli dataset to filter words by", nil, nil, 1, "0-1")

local cmd_create_bitmaps = cmd_create:command("bitmaps", "create bitmaps")
cmd_create_bitmaps:command_target("cmd_create_bitmaps")

local cmd_create_bitmaps_clustered = cmd_create_bitmaps:command("clustered", "create bitmaps from clusters")
base_flags(cmd_create_bitmaps_clustered)
cmd_create_bitmaps_clustered
  :option("--name", "name of created bitmaps", nil, nil, 1, 1)
cmd_create_bitmaps_clustered
  :option("--clusters", "name of clusters to use", nil, nil, 1, 1)
cmd_create_bitmaps_clustered
  :option("--min-similarity", "minimum similarity required to set bit", 0.5, tonumber, 1, "0-1")
cmd_create_bitmaps_clustered
  :option("--min-set", "minimum number of bits to set", 1, tonumber, 1, "0-1")
cmd_create_bitmaps_clustered
  :option("--max-set", "maximum number of bits to set", nil, nil, 1, 1)

local cmd_create_bitmaps_auto_encoded = cmd_create_bitmaps:command("auto-encoded", "create bitmaps via auto-encoder")
base_flags(cmd_create_bitmaps_auto_encoded)
cmd_create_bitmaps_auto_encoded
  :option("--name", "name of created bitmaps", nil, nil, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--words", "name of words to use", nil, nil, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--encoded-bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--threshold-levels", "number of input dimension thresholds", nil, tonumber, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--train-test-ratio", "ratio of train to test examples", nil, tonumber, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--state-bits", "Tsetlin Machine state bits", 8, tonumber, 1, "0-1")
cmd_create_bitmaps_auto_encoded
  :option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--active-clause", "Tsetlin Machine drop clause", 0.75, tonumber, 1, "0-1")
cmd_create_bitmaps_auto_encoded
  :option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_bitmaps_auto_encoded
  :option("--boost-true-positive",
  "Tsetlin Machine boost true positive", "false", fun.bind(op.eq, "true"), 1, "0-1")
    :choices({ "true", "false" })
cmd_create_bitmaps_auto_encoded
  :option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, "0-1")
cmd_create_bitmaps_auto_encoded
  :option("--max-records", "Max number records to use in training", nil, tonumber, 1, "0-1")
cmd_create_bitmaps_auto_encoded
  :option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local cmd_create_bitmaps_encoded = cmd_create_bitmaps:command("encoded", "create bitmaps via a siamese encoder")
base_flags(cmd_create_bitmaps_encoded)
cmd_create_bitmaps_encoded
  :option("--name", "name of created bitmaps", nil, nil, 1, 1)
cmd_create_bitmaps_encoded
  :option("--words", "name of words to use", nil, nil, 1, 1)
cmd_create_bitmaps_encoded
  :option("--encoded-bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--threshold-levels", "number of input dimension thresholds", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--train-test-ratio", "ratio of train to test examples", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--margin", "margin for triplet loss", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--similarity-positive", "threshold for considering a relationship an entailment", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--similarity-negative", "threshold for considering a relationship a contradiction", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--state-bits", "Tsetlin Machine state bits", 8, tonumber, 1, "0-1")
cmd_create_bitmaps_encoded
  :option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--active-clause", "Tsetlin Machine drop clause", 0.75, tonumber, 1, "0-1")
cmd_create_bitmaps_encoded
  :option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_bitmaps_encoded
  :option("--boost-true-positive",
  "Tsetlin Machine boost true positive", "false", fun.bind(op.eq, "true"), 1, "0-1")
    :choices({ "true", "false" })
cmd_create_bitmaps_encoded
  :option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, "0-1")
cmd_create_bitmaps_encoded
  :option("--max-records", "Max number records to use in training", nil, tonumber, 1, "0-1")
cmd_create_bitmaps_encoded
  :option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local cmd_create_bitmaps_thresholded = cmd_create_bitmaps:command("thresholded", "create bitmaps via thresholding")
base_flags(cmd_create_bitmaps_thresholded)
cmd_create_bitmaps_thresholded
  :option("--name", "name of created bitmaps", nil, nil, 1, 1)
cmd_create_bitmaps_thresholded
  :option("--words", "name of words to use", nil, nil, 1, 1)
cmd_create_bitmaps_thresholded
  :option("--threshold-levels", "number of input dimension thresholds", nil, tonumber, 1, 1)

local cmd_create_encoder = cmd_create:command("encoder", "create an encoder")
cmd_create_encoder:command_target("cmd_create_encoder")

local cmd_create_encoder_recurrent = cmd_create_encoder:command("recurrent", "create a recurrent encoder")
base_flags(cmd_create_encoder_recurrent)
cmd_create_encoder_recurrent:option("--name", "name of created encoder", nil, nil, 1, 1)
cmd_create_encoder_recurrent:option("--bitmaps", "name of word bitmaps to use", nil, nil, 1, 1)
cmd_create_encoder_recurrent:option("--sentences", "name of NLI dataset to encode", nil, nil, 1, 1)
cmd_create_encoder_recurrent:option("--positional-bits", "number of bits for positional encoding", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--encoded-bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--max-words", "max number of words to consume", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--margin", "margin for triplet loss", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--train-test-ratio", "ratio of train to test examples", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--state-bits", "Tsetlin Machine state bits", 8, tonumber, 1, "0-1")
cmd_create_encoder_recurrent:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 1, 1)
cmd_create_encoder_recurrent:option("--active-clause", "Tsetlin Machine drop clause", 0.75, tonumber, 1, "0-1")
cmd_create_encoder_recurrent:option("--boost-true-positive",
  "Tsetlin Machine boost true positive", "false", fun.bind(op.eq, "true"), 1, "0-1")
    :choices({ "true", "false" })
cmd_create_encoder_recurrent:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, "0-1")
cmd_create_encoder_recurrent:option("--max-records", "Max number records to use in training", nil, tonumber, 1, "0-1")
cmd_create_encoder_recurrent:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local cmd_create_encoder_windowed = cmd_create_encoder:command("windowed", "create a windowed encoder")
base_flags(cmd_create_encoder_windowed)
cmd_create_encoder_windowed:option("--name", "name of created encoder", nil, nil, 1, 1)
cmd_create_encoder_windowed:option("--bitmaps", "name of word bitmaps to use", nil, nil, 1, 1)
cmd_create_encoder_windowed:option("--sentences", "name of NLI dataset to encode", nil, nil, 1, 1)
cmd_create_encoder_windowed:option("--encoded-bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--window-size", "max number of words in a window", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--margin", "margin for triplet loss", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--train-test-ratio", "ratio of train to test examples", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--state-bits", "Tsetlin Machine state bits", 8, tonumber, 1, "0-1")
cmd_create_encoder_windowed:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 1, 1)
cmd_create_encoder_windowed:option("--active-clause", "Tsetlin Machine drop clause", 0.75, tonumber, 1, "0-1")
cmd_create_encoder_windowed:option("--boost-true-positive",
  "Tsetlin Machine boost true positive", "false", fun.bind(op.eq, "true"), 1, "0-1")
    :choices({ "true", "false" })
cmd_create_encoder_windowed:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, "0-1")
cmd_create_encoder_windowed:option("--max-records", "Max number records to use in training", nil, tonumber, 1, "0-1")
cmd_create_encoder_windowed:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local args = parser:parse()

local db = init_db(args.cache)

if args.cmd == "load" and args.cmd_load == "words" then
  words.load_words(db, args)
elseif args.cmd == "load" and args.cmd_load == "sentences" then
  sentences.load_sentences(db, args)
elseif args.cmd == "create" and args.cmd_create == "clusters" then
  clusters.create_clusters(db, args)
elseif args.cmd == "create" and args.cmd_create == "bitmaps" and args.cmd_create_bitmaps == "clustered" then
  bitmaps.create_bitmaps_clustered(db, args)
elseif args.cmd == "create" and args.cmd_create == "bitmaps" and args.cmd_create_bitmaps == "auto-encoded"  then
  bitmaps.create_bitmaps_auto_encoded(db, args)
elseif args.cmd == "create" and args.cmd_create == "bitmaps" and args.cmd_create_bitmaps == "encoded"  then
  bitmaps.create_bitmaps_encoded(db, args)
elseif args.cmd == "create" and args.cmd_create == "bitmaps" and args.cmd_create_bitmaps == "thresholded"  then
  bitmaps.create_bitmaps_thresholded(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" and args.cmd_create_encoder == "recurrent" then
  encoder.create_encoder_recurrent(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" and args.cmd_create_encoder == "windowed" then
  encoder.create_encoder_windowed(db, args)
else
  print(parser:get_usage())
  os.exit(1)
end
