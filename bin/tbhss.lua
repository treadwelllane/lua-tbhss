local argparse = require("argparse")
local serialize = require("santoku.serialize") -- luacheck: ignore

local init_db = require("tbhss.db")
local glove = require("tbhss.glove")
local clusters = require("tbhss.clusters")
local bitmaps = require("tbhss.bitmaps")
local sts = require("tbhss.sts")
local encoder = require("tbhss.encoder")
local contextualizer = require("tbhss.contextualizer")

local fun = require("santoku.functional")
local op = require("santoku.op")

local parser = argparse()
  :name("tbhss")
  :description("TBHSS sentence similarity")

parser:command_target("cmd")

local function base_flags (cmd)
  cmd:option("--cache", "cache db file", nil, nil, 1, 1)
end

local cmd_load = parser:command("load", "load data into the cache")
cmd_load:command_target("cmd_load")

local cmd_load_embeddings = cmd_load:command("embeddings", "load embeddings")
base_flags(cmd_load_embeddings)
cmd_load_embeddings:option("--name", "name of loaded embeddings", nil, nil, 1, 1)
cmd_load_embeddings:option("--file", "path to input embeddings file", nil, nil, 1, 1)

local cmd_load_sts = cmd_load:command("sts", "load sentence similarity dataset")
base_flags(cmd_load_sts)
cmd_load_sts:option("--name", "name of loaded dataset", nil, nil, 1, 1)
cmd_load_sts:option("--file", "path to sts dataset file", nil, nil, 1, 1)

local cmd_create = parser:command("create")
cmd_create:command_target("cmd_create")

local cmd_create_clusters = cmd_create:command("clusters", "create clusters")
base_flags(cmd_create_clusters)
cmd_create_clusters:option("--name", "name of created clusters", nil, nil, 1, 1)
cmd_create_clusters:option("--embeddings", "name of embeddings to cluster", nil, nil, 1, 1)
cmd_create_clusters:option("--clusters", "number of clusters", nil, tonumber, 1, 1)

local cmd_create_encoder = cmd_create:command("encoder", "create an encoder")
base_flags(cmd_create_encoder)
cmd_create_encoder:option("--name", "name of created encoder", nil, nil, 1, 1)
cmd_create_encoder:option("--bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_encoder:option("--embeddings", "name of embeddings to encode", nil, nil, 1, 1)
cmd_create_encoder:option("--threshold-levels", "number of levels for number discretization", nil, tonumber, 1, 1)
cmd_create_encoder:option("--max-records", "max number of records to read for training", nil, tonumber, 1, "0-1")
cmd_create_encoder:option("--train-test-ratio", "ratio of train embeddings to test embeddings", nil, tonumber, 1, 1)
cmd_create_encoder:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_encoder:option("--state-bits", "Tsetlin Machine state bits", 8, tonumber, 1, "0-1")
cmd_create_encoder:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_encoder:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 1, 1)
cmd_create_encoder:option("--update-probability", "Tsetlin Machine update probability", 2, tonumber, 1, "0-1")
cmd_create_encoder:option("--drop-clause", "Tsetlin Machine drop clause", 0.75, tonumber, 1, "0-1")
cmd_create_encoder:option("--boost-true-positive", "Tsetlin Machine boost true positive", "false", fun.bind(op.eq, "true"), 1, "0-1"):choices({ "true", "false" })
cmd_create_encoder:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, "0-1")
cmd_create_encoder:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local cmd_create_contextualizer = cmd_create:command("contextualizer", "create a contextualizer")
base_flags(cmd_create_contextualizer)
cmd_create_contextualizer:option("--name", "name of created contextualizer", nil, nil, 1, 1)
cmd_create_contextualizer:option("--sts", "name of sts dataset to use", nil, nil, 1, 1)
cmd_create_contextualizer:mutex(
  cmd_create_contextualizer:option("--clusters", "name of clusters to use", nil, nil, 1, 1),
  cmd_create_contextualizer:option("--encoder", "name of encoder to use", nil, nil, 1, 1))
cmd_create_contextualizer:option("--bits", "number of bits in encoded bitmaps", nil, tonumber, 1, 1)
cmd_create_contextualizer:option("--waves", "number of waves for positional encoding", nil, tonumber, 1, 1)
cmd_create_contextualizer:option("--wave-period", "wave period for positional encoding", 10000, tonumber, 1, "0-1")
cmd_create_contextualizer:option("--train-test-ratio", "ratio of train embeddings to test embeddings", nil, tonumber, 1, 1)
cmd_create_contextualizer:option("--clauses", "Tsetlin Machine clauses", nil, tonumber, 1, 1)
cmd_create_contextualizer:option("--state-bits", "Tsetlin Machine state bits", 8, tonumber, 1, "0-1")
cmd_create_contextualizer:option("--threshold", "Tsetlin Machine threshold", nil, tonumber, 1, 1)
cmd_create_contextualizer:option("--specificity", "Tsetlin Machine specificity", nil, tonumber, 1, 1)
cmd_create_contextualizer:option("--update-probability", "Tsetlin Machine update probability", 2, tonumber, 1, "0-1")
cmd_create_contextualizer:option("--drop-clause", "Tsetlin Machine drop clause", 0.75, tonumber, 1, "0-1")
cmd_create_contextualizer:option("--boost-true-positive", "Tsetlin Machine boost true positive", "false", fun.bind(op.eq, "true"), 1, "0-1"):choices({ "true", "false" })
cmd_create_contextualizer:option("--evaluate-every", "Evaluation frequency", 5, tonumber, 1, "0-1")
cmd_create_contextualizer:option("--epochs", "Number of epochs", nil, tonumber, 1, 1)

local cmd_create_bitmaps = cmd_create:command("bitmaps", "create pre-computed bitmaps")
cmd_create_bitmaps:command_target("cmd_create_bitmaps")

local cmd_create_bitmaps_clustered = cmd_create_bitmaps:command("clustered", "create bitmaps from clusters")
base_flags(cmd_create_bitmaps_clustered)
cmd_create_bitmaps_clustered:option("--name", "name of created bitmaps", nil, nil, 1, 1)
cmd_create_bitmaps_clustered:option("--clusters", "name of clusters to use", nil, nil, 1, 1)
cmd_create_bitmaps_clustered:option("--min-similarity", "minimum similarity required to set bit", 0.5, tonumber, 1, "0-1")
cmd_create_bitmaps_clustered:option("--min-set", "minimum number of bits to set", 1, tonumber, 1, "0-1")
cmd_create_bitmaps_clustered:option("--max-set", "maximum number of bits to set", nil, nil, 1, 1)

local cmd_create_bitmaps_encoded = cmd_create_bitmaps:command("encoded", "create bitmaps from an encoder")
base_flags(cmd_create_bitmaps_encoded)
cmd_create_bitmaps_encoded:option("--name", "name of created bitmaps", nil, nil, 1, 1)
cmd_create_bitmaps_encoded:option("--encoder", "name of encoder", nil, nil, 1, 1)

local args = parser:parse()

local db = init_db(args.cache)

if args.cmd == "load" and args.cmd_load == "embeddings" then
  glove.load_embeddings(db, args)
elseif args.cmd == "load" and args.cmd_load == "sts" then
  sts.load_sts(db, args)
elseif args.cmd == "create" and args.cmd_create == "clusters" then
  clusters.create_clusters(db, args)
elseif args.cmd == "create" and args.cmd_create == "encoder" then
  encoder.create_encoder(db, args)
elseif args.cmd == "create" and args.cmd_create == "contextualizer" then
  contextualizer.create_contextualizer(db, args)
elseif args.cmd == "create" and args.cmd_create == "bitmaps" and args.cmd_create_bitmaps == "clustered" then
  bitmaps.create_clustered(db, args)
elseif args.cmd == "create" and args.cmd_create == "bitmaps" and args.cmd_create_bitmaps == "encoded" then
  bitmaps.create_encoded(db, args)
else
  print(parser:get_usage())
  os.exit(1)
end
