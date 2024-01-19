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

  local words, word_vectors = glove.load_vectors(args.input, args.limit_words)
  local word_numbers = cluster.cluster_vectors(words, word_vectors, args.num_clusters)

  local handle = assert(io.open(args.output, "w"))

  for i = 1, #words do
    handle:write(string.format("%s\t%d\n", words[i], word_numbers[words[i]]))
  end

  handle:close()

end
