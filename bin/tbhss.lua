local argparse = require("argparse")

local init_db = require("tbhss.db")
local glove = require("tbhss.glove")
local cluster = require("tbhss.cluster")

local fs = require("santoku.fs")
local arr = require("santoku.array")
local mtx = require("tbhss.blas")

local parser = argparse()
  :name("tbhss")
  :description("TBHSS sentence similarity")

parser:command_target("command")

local c_convert = parser:command("convert-glove", "convert a glove model")

c_convert
  :option("--input", "input glove file")
  :args(1)
  :count(1)

c_convert
  :option("--output", "output glove file")
  :args(1)
  :count(1)

c_convert
  :option("--tag", "cache db tag")
  :args(1)
  :count("0-1")

c_convert
  :option("--db-file", "cache db file")
  :args(1)
  :count(1)

c_convert
  :option("--num-clusters", "total number of clusters")
  :convert(tonumber)
  :args(1)
  :count(1)

c_convert
  :option("--max-iterations", "max iterations for clustering")
  :convert(tonumber)
  :args(1)
  :count("0-1")

local args = parser:parse()

if args.command == "convert-glove" then

  local db = init_db(args.db_file)

  local model =
    db.get_model_by_tag(args.tag or args.input)

  local model, word_matrix, _, word_names =
    glove.load_vectors(db, model, args.input, args.tag)

  local _, distance_matrix =
    cluster.cluster_vectors(db, model, word_matrix,
      args.num_clusters,
      args.max_iterations)

  print("Writing output file")

  local out = {}

  fs.with(args.output, "w", function (fh)
    for i = 1, mtx.rows(distance_matrix) do
      if i > 1 then
        fs.write(fh, "\n")
      end
      out[1] = word_names[i]
      for j = 1, mtx.columns(distance_matrix) do
        out[1 + (j * 2 - 1)] = j
        out[1 + (j * 2)] = mtx.get(distance_matrix, i, j)
      end
      fs.write(fh, arr.concat(out, "\t"))
    end
  end)

end
