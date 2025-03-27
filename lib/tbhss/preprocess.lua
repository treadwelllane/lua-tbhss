local str = require("santoku.string")
local varg = require("santoku.varg")
local fs = require("santoku.fs")
local num = require("santoku.num")
local it = require("santoku.iter")
local tbl = require("santoku.table")
local arr = require("santoku.array")

local function write_sentences (sentences, file, s, e)
  local tmp = {}
  s = s or 1
  e = e or #sentences
  for i = s, e do
    local t = sentences[i]
    arr.push(tmp, t, "\n")
  end
  fs.writefile(file, arr.concat(tmp))
end

local function write_triplets (triplets, file, s, e)
  local tmp = {}
  s = s or 1
  e = e or #triplets
  for i = s, e do
    local t = triplets[i]
    arr.push(tmp, t.anchor, "\t", t.positive, "\t", t.negative, "\n")
  end
  fs.writefile(file, arr.concat(tmp))
end

local function write_samples (samples, file, s, e)
  local tmp = {}
  s = s or 1
  e = e or #samples
  for i = s, e do
    local t = samples[i]
    arr.push(tmp, t.label, "\t", t.review, "\n")
  end
  fs.writefile(file, arr.concat(tmp))
end

local function sample_sentences (samples, s, e)
  local out = {}
  e = e or #samples
  for i = s, e do
    local p = samples[i]
    out[p.review] = true
  end
  out = it.collect(it.keys(out))
  arr.shuffle(out)
  return out
end

local function sentences_flattened (sentences)
  local out = {}
  for s in pairs(sentences) do
    arr.push(out, s)
  end
  arr.shuffle(out)
  return out
end

local function triplets_flattened (triplets)
  local out = {}
  for a, ls in pairs(triplets) do
    if ls.entailment then
      for e in pairs(ls.entailment) do
        for n in it.chain(varg.map(it.pairs, ls.neutral or {}, ls.contradiction or {})) do
          arr.push(out, {
            anchor = a,
            positive = e,
            negative = n
          })
        end
      end
    end
  end
  return out
end

local function triplet_sentences (triplets, s, e)
  local out = {}
  s = s or 1
  e = e or #triplets
  for i = s, e do
    local t = triplets[i]
    out[t.anchor] = true
    out[t.positive] = true
    out[t.negative] = true
  end
  out = it.collect(it.keys(out))
  arr.shuffle(out)
  return out
end

local valid_labels = it.set(it.vals({ "entailment", "contradiction", "neutral" }))

local function snli (args)
  print("Processing SNLI")
  if not (args.triplets or args.sentences) then
    return
  end
  local triplets = args.triplets and {}
  local sentences_only = not args.triplets and {}
  local n = 0
  for i = 1, #args.inputs do
    if args.max and n > args.max then
      break
    end
    print("Reading", args.inputs[i])
    for line in it.drop(1, fs.lines(args.inputs[i])) do
      if args.max and n > args.max then
        break
      end
      local chunks = str.splits(line, "\t")
      local label = str.sub(chunks())
      if valid_labels[label] then
        chunks = it.drop(4, chunks)
        local a = str.sub(chunks())
        local b = str.sub(chunks())
        if triplets then
          tbl.update(triplets, a, label, function (ss)
            ss = ss or {}
            ss[b] = true
            return ss
          end)
        end
        if sentences_only then
          sentences_only[a] = true
          sentences_only[b] = true
        end
        n = n + 1
      end
    end
  end
  if triplets then
    print("Generating triplets")
    triplets = triplets_flattened(triplets)
    arr.shuffle(triplets)
    local train_end = args.train_test_ratio and num.floor(#triplets * args.train_test_ratio)
    if train_end then
      write_triplets(triplets, args.triplets[1], 1, train_end)
      write_triplets(triplets, args.triplets[2], train_end + 1, #triplets)
      if args.sentences then
        write_sentences(triplet_sentences(triplets, 1, train_end), args.sentences[1])
        write_sentences(triplet_sentences(triplets, train_end + 1, #triplets), args.sentences[2])
      end
    else
      write_triplets(triplets, args.triplets[1])
      if args.sentences then
        write_sentences(triplet_sentences(triplets), args.sentences[1])
      end
    end
  end
  if sentences_only then
    print("Generating sentences")
    sentences_only = sentences_flattened(sentences_only)
    arr.shuffle(sentences_only)
    local train_end = args.train_test_ratio and num.floor(#sentences_only * args.train_test_ratio)
    if train_end then
      write_sentences(sentences_only, args.sentences[1], 1, train_end)
      write_sentences(sentences_only, args.sentences[2], train_end + 1, #sentences_only)
    else
      write_sentences(sentences_only, args.sentences[1])
    end
  end
end

local function map_imdb_files (label, fp)
  local review = fs.readfile(fp)
  review = str.gsub(review, "[\t\n]", "")
  return { label = label, review = review }
end

local function imdb (args)
  print("Processing IMDB")
  if not (args.samples or args.sentences) then
    return
  end
  local samples = args.samples and {}
  local sentences_only = not args.samples and {}
  for i = 1, #args.dirs do
    print("Reading", args.dirs[i])
    local pos = it.map(map_imdb_files, it.paste(0, fs.files(fs.join(args.dirs[i], "pos"), true)))
    local neg = it.map(map_imdb_files, it.paste(1, fs.files(fs.join(args.dirs[i], "neg"), true)))
    while not args.max or #samples < args.max * 2  do
      local p = pos()
      local n = neg()
      if not p or not n then
        break
      end
      if samples then
        arr.push(samples, p, n)
      end
      if sentences_only then
        sentences_only[p] = true
        sentences_only[n] = true
      end
    end
  end
  if samples then
    print("Generating samples")
    arr.shuffle(samples)
    local train_end = args.train_test_ratio and num.floor(#samples * args.train_test_ratio)
    if train_end then
      write_samples(samples, args.samples[1], 1, train_end)
      write_samples(samples, args.samples[2], train_end + 1, #samples)
      if args.sentences then
        write_sentences(sample_sentences(samples, 1, train_end), args.sentences[1])
        write_sentences(sample_sentences(samples, train_end + 1, #samples), args.sentences[2])
      end
    else
      write_samples(samples, args.samples[1])
      if args.sentences then
        write_sentences(sample_sentences(samples), args.sentences[1])
      end
    end
  end
  if sentences_only then
    print("Generating sentences")
    sentences_only = sentences_flattened(sentences_only)
    arr.shuffle(sentences_only)
    local train_end = args.train_test_ratio and num.floor(#sentences_only * args.train_test_ratio)
    if train_end then
      write_sentences(sentences_only, args.sentences[1], 1, train_end)
      write_sentences(sentences_only, args.sentences[2], train_end + 1, #sentences_only)
    else
      write_sentences(sentences_only, args.sentences[1])
    end
  end
end

return {
  snli = snli,
  imdb = imdb,
}
