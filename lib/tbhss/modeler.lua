local bm = require("santoku.bitmap")
local mtx = require("santoku.matrix")
local str = require("santoku.string")
local arr = require("santoku.array")
local err = require("santoku.error")
local num = require("santoku.num")
local it = require("santoku.iter")
local utc = require("santoku.utc")
local fs = require("santoku.fs")

local compressor = require("santoku.bitmap.compressor")
local tokenizer = require("tbhss.tokenizer")

num.round_multiple = function (n, m)
  return num.ceil(n / m) * m
end

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

  local data, supervise
  if (args.sentences and args.samples) or not (args.sentences or args.samples) then
    return err.error("either samples or sentences must be provided")
  elseif args.sentences then
    data = args.sentences
    supervise = false
  elseif args.samples then
    data = args.samples
    supervise = true
  else
    -- Shouldn't get here
    return err.error("Unexpected, this is a bug!")
  end

  local n_labels, labels, corpus

  corpus = type(data) ~= "table"
    and it.collect(fs.lines(data))
    or it.collect(it.flatten(it.map(fs.lines, it.ivals(data))))

  if supervise then
    labels = {}
    n_labels = 0
    for i = 1, #corpus do
      local r = corpus[i]
      local l, s = str.match(r, "^([^\t]+)\t(.*)")
      if not l or not s then
        return err.error("Error parsing line:", r)
      end
      local ln = tonumber(l)
      if not ln then
        return err.error("Label is not a number", l)
      end
      if ln + 1 > n_labels  then
        n_labels = ln + 1
      end
      corpus[i] = s
      labels[i] = ln
    end
    labels = mtx.raw(mtx.create(labels), nil, nil, "u32")
  end

  local samples = #corpus

  print("Creating tokenizer", n_labels)
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
      labels = labels,
      supervision = args.supervision,
      n_labels = n_labels,
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
  if not m.compressor then
    m.visible = num.round_multiple(m.visible, 128)
  end
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
