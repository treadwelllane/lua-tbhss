local bm = require("santoku.bitmap")
local str = require("santoku.string")
local it = require("santoku.iter")
local utc = require("santoku.utc")
local fs = require("santoku.fs")

local compressor = require("santoku.bitmap.compressor")
local tokenizer = require("tbhss.tokenizer")

local function create (db, args)

  local corpus = it.collect(fs.lines(args.sentences))
  local samples = #corpus

  print("Creating tokenizer")
  local tokenizer = tokenizer.create({
    max_df = args.max_df,
    min_df = args.min_df,
    max_len = args.max_len,
    min_len = args.min_len,
    ngrams = 1
  })

  print("Training tokenizer")
  tokenizer.train({ corpus = corpus })
  tokenizer.finalize()
  local features = tokenizer.features()
  print("Features: ", features)

  print("Tokenizing corpus")
  tokenizer.tokenize(corpus)

  print("Packing bitmaps")
  corpus = bm.matrix(corpus, features)

  print("Creating compressor")
  local compressor = compressor.create({
    visible = features,
    hidden = args.hidden,
  })

  print("Training compressor")
  local stopwatch = utc.stopwatch()
  compressor.train({
    corpus = corpus,
    samples = samples,
    iterations = args.iterations,
    each = function (i, tc)
      local duration, total_duration = stopwatch()
      str.printf("Epoch %3d  %10.4f  %8.2fs  %8.2fs\n",
        i, tc, duration, total_duration)
    end
  })

  local tfp = fs.join(fs.dirname(db.file), args.name .. ".tokenizer.bin")
  local cfp = fs.join(fs.dirname(db.file), args.name .. ".compressor.bin")

  tokenizer.persist(tfp)
  compressor.persist(cfp)

  db.add_modeler(args.name, features, args.hidden, tfp, cfp)

end

local function open (db, name)
  local m = db.get_modeler(name)
  m.tokenizer = tokenizer.load(m.tokenizer, nil)
  m.compressor = compressor.load(m.compressor, nil)
  m.model = function (s)
    return m.compressor.compress(m.tokenizer.tokenize(s))
  end
  return m
end

return {
  create = create,
  open = open,
}
