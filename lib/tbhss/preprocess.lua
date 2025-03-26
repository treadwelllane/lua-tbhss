local str = require("santoku.string")
local varg = require("santoku.varg")
local fs = require("santoku.fs")
local num = require("santoku.num")
local it = require("santoku.iter")
local err = require("santoku.error")
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

local function write_pairs (pairs, file, s, e)
  local tmp = {}
  s = s or 1
  e = e or #pairs
  for i = s, e do
    local t = pairs[i]
    arr.push(tmp, t.a, "\t", t.b, "\t", t.label, "\n")
  end
  fs.writefile(file, arr.concat(tmp))
end

local function pair_sentences (pairs, s, e)
  local out = {}
  s = s or 1
  e = e or #pairs
  for i = s, e do
    local p = pairs[i]
    out[p.a] = true
    out[p.b] = true
  end
  out = it.collect(it.keys(out))
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
  if not (args.pairs or args.triplets or args.sentences) then
    return
  end
  local pairs = args.pairs and {}
  local triplets = args.triplets and {}
  local sentences_only = not args.pairs and not args.triplets and {}
  for i = 1, #args.inputs do
    print("Reading", args.inputs[i])
    for line in it.drop(1, fs.lines(args.inputs[i])) do
      local chunks = str.splits(line, "\t")
      local label = str.sub(chunks())
      if valid_labels[label] then
        chunks = it.drop(4, chunks)
        local a = str.sub(chunks())
        local b = str.sub(chunks())
        if pairs then
          arr.push(pairs, { label = label, a = a, b = b })
        end
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
      end
    end
  end
  if pairs then
    print("Generating pairs")
    arr.shuffle(pairs)
    local train_end = args.train_test_ratio and num.floor(#pairs * args.train_test_ratio)
    local train_start = train_end and 1
    if train_end then
      write_pairs(pairs, args.pairs[1], 1, train_end)
      write_pairs(pairs, args.pairs[2], train_end + 1, #pairs)
      if args.sentences then
        write_sentences(pair_sentences(pairs, 1, train_end), args.sentences[1])
        write_sentences(pair_sentences(pairs, train_end + 1, #pairs), args.sentences[2])
      end
    else
      write_pairs(pairs, args.pairs[1])
      if sentences then
        write_sentences(pair_sentences(pairs), args.sentences[1])
      end
    end
  end
  if triplets then
    print("Generating triplets")
    triplets = triplets_flattened(triplets)
    arr.shuffle(triplets)
    local train_end = args.train_test_ratio and num.floor(#triplets * args.train_test_ratio)
    local train_start = train_end and 1
    if train_end then
      write_triplets(triplets, args.triplets[1], 1, train_end)
      write_triplets(triplets, args.triplets[2], train_end + 1, #triplets)
      if args.sentences then
        write_sentences(triplet_sentences(triplets, 1, train_end), args.sentences[1])
        write_sentences(triplet_sentences(triplets, train_end + 1, #triplets), args.sentences[2])
      end
    else
      write_triplets(triplets, args.triplets[1])
      if sentences then
        write_sentences(triplet_sentences(triplets), args.sentences[1])
      end
    end
  end
  if sentences_only then
    print("Generating sentences")
    sentences_only = sentences_flattened(sentences_only)
    arr.shuffle(sentences_only)
    local train_end = args.train_test_ratio and num.floor(#sentences_only * args.train_test_ratio)
    local train_start = train_end and 1
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
}
