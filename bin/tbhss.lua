-- luacheck: no max line length

local argparse = require("argparse")
local serialize = require("santoku.serialize") -- luacheck: ignore
local str = require("santoku.string")

local init_db = require("tbhss.db")
local words = require("tbhss.words")
local modeler = require("tbhss.modeler")
local clusters = require("tbhss.clusters")
local encoder = require("tbhss.encoder")
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

local cmd_process_snli = cmd_process:command("snli", "parse SNLI dataset into triplets and sentences")
cmd_process_snli:option("--inputs", "Stanford NLI formatted input files", nil, nil, "+", 1)
cmd_process_snli:option("--train-test-ratio", "ratio of train to test triplets", nil, tonumber, 1, "?")
cmd_process_snli:option("--triplets", "file to write triplets to", nil, nil, "+", "?")
cmd_process_snli:option("--sentences", "file to write sentences to", nil, nil, "+", "?")
cmd_process_snli:option("--max", "max number of triplets", nil, tonumber, 1, "?")

local cmd_process_imdb = cmd_process:command("imdb", "parse IMDB dataset into samples and sentences")
cmd_process_imdb:option("--dirs", "Path to IMDB dataset train/test subfolders", nil, nil, "+", 1)
cmd_process_imdb:option("--train-test-ratio", "ratio of train to test samples", nil, tonumber, 1, "?")
cmd_process_imdb:option("--samples", "file to write samples to", nil, nil, "+", "?")
cmd_process_imdb:option("--sentences", "file to write sentences to", nil, nil, "+", "?")
cmd_process_imdb:option("--max", "max number of samples", nil, tonumber, 1, "?")

local cmd_load = parser:command("load", "load data into the cache")
cmd_load:command_target("cmd_load")

local cmd_load_words = cmd_load:command("words", "load words")
base_flags(cmd_load_words)
cmd_load_words:option("--name", "name of loaded words", nil, nil, 1, 1)
cmd_load_words:option("--file", "path to input words file", nil, nil, 1, 1)

local cmd_create = parser:command("create")
cmd_create:command_target("cmd_create")

local cmd_create_clusters = cmd_create:command("clusters", "create clusters")
base_flags(cmd_create_clusters)
cmd_create_clusters:option("--name", "name of created clusters", nil, nil, 1, 1)
cmd_create_clusters:option("--words", "name of words to cluster", nil, nil, 1, 1)
cmd_create_clusters:option("--algorithm", "clustering algorithm", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, "+", "0-1")
cmd_create_clusters:option("--filter", "path to words.txt to filter by", nil, nil, 1, "0-1")

local cmd_create_modeler = cmd_create:command("modeler", "create modeler")
base_flags(cmd_create_modeler)
cmd_create_modeler:option("--name", "name of created modeler", nil, nil, 1, 1)
cmd_create_modeler:option("--sentences", "path to sentences.txt to train on", nil, nil, 1, 1)
cmd_create_modeler:option("--vocab", "vocab size for bpe", nil, tonumber, 1, 1)
cmd_create_modeler:option("--position", "wavelength, dimensions, and buckets for sinusoidal positions", nil, function (v)
  return str.match(v, "^%-?%d*%.?%d+$") and tonumber(v) or v
end, 3, 1)
cmd_create_modeler:option("--hidden", "number of hidden features to capture", nil, tonumber, 1, 1)
cmd_create_modeler:option("--iterations", "Number of iterations", nil, tonumber, 1, 1)

local cmd_create_classifier = cmd_create:command("classifier", "create a classifier")
base_flags(cmd_create_classifier)
cmd_create_classifier:option("--name", "name of created classifier", nil, nil, 1, 1)
cmd_create_classifier:option("--samples", "paths to train and test samples.txt files", nil, nil, 2, 1)
cmd_create_classifier:option("--modeler", "name of modeler to use", nil, nil, 1, 1)
cmd_create_classifier:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_classifier:option("--state-bits", "Tsetlin Machine state bits", nil, tonumber, 1, 1)
cmd_create_classifier:option("--target", "Tsetlin Machine target", nil, tonumber, 1, 1)
cmd_create_classifier:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 2, 1)
cmd_create_classifier:option("--active-clause", "Tsetlin Machine active clause", nil, tonumber, 1, 1)
cmd_create_classifier:option("--boost-true-positive", "Tsetlin Machine boost true positive", nil, fun.bind(op.eq, "true"), 1, 1):choices({ "true", "false" })
cmd_create_classifier:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, 1)
cmd_create_classifier:option("--iterations", "Number of iterations", nil, tonumber, 1, 1)

local cmd_create_encoder = cmd_create:command("encoder", "create an encoder")
base_flags(cmd_create_encoder)
cmd_create_encoder:option("--name", "name of created encoder", nil, nil, 1, 1)
cmd_create_encoder:option("--triplets", "paths to train and test triplets.txt files", nil, nil, 2, 1)
cmd_create_encoder:option("--modeler", "name of modeler to use", nil, nil, 1, 1)
cmd_create_encoder:option("--hidden", "number of hidden features to train", nil, tonumber, 1, 1)
cmd_create_encoder:option("--margin", "margin for triplet loss", nil, tonumber, 1, 1)
cmd_create_encoder:option("--loss-alpha", "scale for loss function", nil, tonumber, 1, 1)
cmd_create_encoder:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_encoder:option("--state-bits", "Tsetlin Machine state bits", nil, tonumber, 1, 1)
cmd_create_encoder:option("--target", "Tsetlin Machine target", nil, tonumber, 1, 1)
cmd_create_encoder:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 2, 1)
cmd_create_encoder:option("--active-clause", "Tsetlin Machine active clause", nil, tonumber, 1, 1)
cmd_create_encoder:option("--boost-true-positive", "Tsetlin Machine boost true positive", nil, fun.bind(op.eq, "true"), 1, 1):choices({ "true", "false" })
cmd_create_encoder:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, 1)
cmd_create_encoder:option("--iterations", "Number of iterations", nil, tonumber, 1, 1)

local args = parser:parse()

if args.cmd == "process" and args.cmd_process == "snli" then
  preprocess.snli(args)
elseif args.cmd == "process" and args.cmd_process == "imdb" then
  preprocess.imdb(args)
  return
end

local db = init_db(args.cache)

if args.cmd == "load" and args.cmd_load == "words" then
  words.load(db, args)
elseif args.cmd == "create" and args.cmd_create == "clusters" then
  clusters.create(db, args)
elseif args.cmd == "create" and args.cmd_create == "modeler" then
  modeler.create(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" then
  encoder.create(db, args)
elseif args.cmd == "create" and args.cmd_create == "classifier" then
  classifier.create(db, args)
else
  print(parser:get_usage())
  os.exit(1)
end
