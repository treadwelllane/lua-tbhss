local bm = require("santoku.bitmap")
local str = require("santoku.string")
local utc = require("santoku.utc")
local arr = require("santoku.array")
local fs = require("santoku.fs")

local compressor = require("santoku.bitmap.compressor")
local tokenizer = require("tbhss.bpe")

local function create (db, args)

  local raw_corpus = fs.readfile(args.sentences)

  print("Creating tokenizer")
  local tokenizer = tokenizer.create({
    vocab = args.vocab,
    wavelength = args.wavelength or args.position[1],
    dimensions = args.dimensions or args.position[2],
    buckets = args.buckets or args.position[3],
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
  local compressor = compressor.create({
    visible = visible,
    hidden = args.hidden,
  })

  print("Training compressor")
  local stopwatch = utc.stopwatch()
  compressor.train({
    corpus = bit_corpus,
    samples = #bit_sentences,
    iterations = args.iterations,
    each = function (i, tc)
      local duration, total_duration = stopwatch()
      str.printf("Epoch %3d  %10.4f  %8.2fs  %8.2fs\n",
        i, tc, duration, total_duration)
    end
  })

  local tdata = tokenizer.persist()
  local cdata = compressor.persist()

  db.add_modeler(args.name, visible, args.hidden, tdata, cdata)

end

local function open (db, name)
  local m = db.get_modeler(name)
  m.tokenizer = tokenizer.load(m.tokenizer, nil, true)
  m.compressor = compressor.load(m.compressor, nil, true)
  m.model = function (s)
    return m.compressor.compress(m.tokenizer.tokenize(s))
  end
  return m
end

return {
  create = create,
  open = open,
}
