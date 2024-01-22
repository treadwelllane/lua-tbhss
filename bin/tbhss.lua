local argparse = require("argparse")

local glove = require("tbhss.glove")
local cluster = require("tbhss.cluster")

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
  :option("--num-clusters", "total number of clusters")
  :args(1)
  :count(1)

c_convert
  :option("--limit-words", "limit the number of words")
  :args(1)
  :count("0-1")

local args = parser:parse()

if args.command == "convert-glove" then

  local word_matrix, _, word_names = glove.load_vectors(
    args.input,
    args.limit_words and tonumber(args.limit_words) or nil)

  local _, distance_matrix = cluster.cluster_vectors(
    word_matrix,
    tonumber(args.num_clusters),
    args.max_iterations and tonumber(args.max_iterations) or nil)

  local handle = assert(io.open(args.output, "w"))
  local out = {}

  for i = 1, distance_matrix:rows() do
    if i > 1 then
      handle:write("\n")
    end
    out[1] = word_names[i]
    for j = 1, distance_matrix:columns() do
      out[1 + (j * 2 - 1)] = j
      out[1 + (j * 2)] = distance_matrix:get(i, j)
    end
    handle:write(table.concat(out, "\t"))
  end

  handle:close()

end
