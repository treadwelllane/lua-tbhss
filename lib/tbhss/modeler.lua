local bm = require("santoku.bitmap")
local str = require("santoku.string")
local arr = require("santoku.array")
local err = require("santoku.error")
local num = require("santoku.num")
local it = require("santoku.iter")
local utc = require("santoku.utc")
local fs = require("santoku.fs")

local compressor = require("santoku.bitmap.compressor")
local tokenizer = require("tbhss.tokenizer")

local function create (db, args)

  if args.compress then
    args.hidden = tonumber(args.hidden or args.compress[1] or nil)
    args.iterations = tonumber(args.iterations or args.compress[2] or nil)
    args.eps = tonumber(args.eps or args.compress[3] or nil)
  else
    args.compress = false
  end

  if db.modeler_exists(args.name) then
    return err.error("Modeler exists", args.name)
  end

  local corpus = type(args.sentences) ~= "table"
    and it.collect(fs.lines(args.sentences))
    or it.collect(it.flatten(it.map(fs.lines, it.ivals(args.sentences))))

  local samples = #corpus

  print("Creating tokenizer")
  local tokenizer = tokenizer.create({
    max_df = args.max_df,
    min_df = args.min_df,
    max_len = args.max_len,
    min_len = args.min_len,
    ngrams = args.ngrams,
    cgrams = args.cgrams,
  })

  print("Training tokenizer")
  tokenizer.train({ corpus = corpus })
  tokenizer.finalize()
  local features = tokenizer.features()
  print("Features: ", features)

  print("Tokenizing corpus", #corpus)
  tokenizer.tokenize(corpus)

  print("Packing bitmaps")
  corpus = bm.matrix(corpus, features)

  local tfp, cfp

  if args.compress then

    print("Creating compressor")
    local compressor = compressor.create({
      visible = features,
      hidden = args.hidden,
      threads = args.threads
    })

    print("Training compressor")
    local stopwatch = utc.stopwatch()
    local tcs = {}
    compressor.train({
      corpus = corpus,
      samples = samples,
      iterations = args.iterations,
      each = function (i, tc)
        local duration, total_duration = stopwatch()
        str.printf("Epoch %3d  %10.4f  %8.2fs  %8.2fs\n",
          i, tc, duration, total_duration)
        arr.push(tcs, tc)
        if args.eps and #tcs >= 10 then
          local tc0 = arr.mean(tcs, #tcs - 9, #tcs - 5)
          local tc1 = arr.mean(tcs, #tcs - 4, #tcs)
          if num.abs(tc0 - tc1) < args.eps then
            return false
          end
        end
      end
    })

    cfp = fs.join(fs.dirname(db.file), args.name .. ".compressor.bin")
    compressor.persist(cfp)

  end

  tfp = fs.join(fs.dirname(db.file), args.name .. ".tokenizer.bin")
  tokenizer.persist(tfp)

  db.add_modeler(args.name, features, args.hidden or features, tfp, args.compress and cfp or nil)

end

local function open (db, name)
  local m = db.get_modeler(name)
  if not m then
    return err.error("Modeler not found", name)
  end
  m.tokenizer = tokenizer.load(m.tokenizer)
  m.compressor = m.compressor and compressor.load(m.compressor)
  m.visible = m.tokenizer.features()
  m.hidden = m.compressor and m.compressor.hidden() or m.visible
  m.model = function (s)
    local n = 1
    s = m.tokenizer.tokenize(s)
    if type(s) == "table" then
      n = #s
      s = bm.matrix(s, m.visible)
    end
    if m.compressor then
      local s0 = m.compressor.compress(s, n)
      return s0
    else
      return s
    end
  end
  return m
end

return {
  create = create,
  open = open,
}
