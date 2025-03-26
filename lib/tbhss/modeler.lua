local err = require("santoku.error")
local bm = require("santoku.bitmap")
local bmc = require("santoku.bitmap.compressor")
local str = require("santoku.string")
local tbl = require("santoku.table")
local arr = require("santoku.array")
local fs = require("santoku.fs")
local bpe = require("tbhss.bpe")

local function create_modeler (db, args)

  local raw_corpus = fs.readfile(args.sentences)

  print("Creating tokenizer")
  local tokenizer = bpe.create({
    vocab = args.vocab,
    wavelength = args.position[1],
    dimensions = args.position[2],
    buckets = args.position[3],
  })

  print("Training tokenizer")
  local visible = tokenizer.train({ corpus = raw_corpus })

  print("Visible: ", visible)
  print("Tokenizing sentences")
  local bit_sentences = {}
  for line in str.gmatch(raw_corpus, "[^\n]+") do
    arr.push(bit_sentences, tokenizer.tokenize(line))
  end

  print("Packing bitmaps")
  local bit_corpus = bm.matrix(bit_sentences, visible);

  print("Creating compressor")
  local compressor = bmc.create({
    visible = visible,
    hidden = args.hidden,
  })

  print("Training compressor")
  local stopwatch = utc.stopwatch()
  local mavg = num.mavg(0.1)
  compressor.train({
    corpus = bit_corpus,
    samples = #bit_sentences,
    iterations = args.iterations,
    each = function (i, tc)
      local duration, total_duration = stopwatch()
      local tc0 = mavg(tc)
      str.printf("Epoch %3d  %6.4f  %6.4f  %3.2f  %3.2f\n",
        i, tc, tc0, duration, total_duration)
    end
  })

  -- TODO: persist compressor and tokenizer
  err.error("todo: save model")

end

return {
  create_modeler = create_modeler
}
