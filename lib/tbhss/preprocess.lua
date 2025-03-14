local str = require("santoku.string")
local varg = require("santoku.varg")
local fs = require("santoku.fs")
local it = require("santoku.iter")
local tbl = require("santoku.table")
local arr = require("santoku.array")

local function write_triplets (triplets, file, s, e)
  local tmp = {}
  for i = s, e do
    local t = triplets[i]
    arr.push(tmp, t.anchor, "\t", t.positive, "\t", t.negative, "\n")
  end
  fs.writefile(file, arr.concat(tmp))
end

local function snli_triplets (args)
  local valid_labels = { "entailment", "contradiction", "neutral" }
  local cache = {}
  for i = 1, #args.inputs do
    for line in it.drop(1, fs.lines(args.inputs[i])) do
      local chunks = str.splits(line, "\t")
      local label = str.sub(chunks())
      if arr.includes(valid_labels, label) then
        chunks = it.drop(2, chunks)
        local a = str.sub(chunks())
        local b = str.sub(chunks())
        tbl.update(cache, a, label, function (ss)
          ss = ss or {}
          ss[b] = true
          return ss
        end)
      end
    end
  end
  local triplets = {}
  while true do
    local a, ls = next(cache)
    if not a then
      break
    end
    cache[a] = nil
    if ls.entailment then
      for e in pairs(ls.entailment) do
        for n in it.chain(varg.map(it.pairs, ls.neutral or {}, ls.contradiction or {})) do
          triplets[#triplets + 1] = {
            anchor = a,
            positive = e,
            negative = n
          }
        end
      end
    end
  end
  arr.shuffle(triplets)
  local train_end = math.floor(#triplets * args.train_test_ratio)
  write_triplets(triplets, args.output_train, 1, train_end)
  write_triplets(triplets, args.output_test, train_end + 1, #triplets)
end

local function write_pairs (pairs, file, s, e)
  local tmp = {}
  for i = s, e do
    local t = pairs[i]
    arr.push(tmp, t.a, "\t", t.b, "\t", t.label, "\n")
  end
  fs.writefile(file, arr.concat(tmp))
end

local function snli_pairs (args)
  local valid_labels = { "entailment", "contradiction", "neutral" }
  local pairs = {}
  for i = 1, #args.inputs do
    for line in it.drop(1, fs.lines(args.inputs[i])) do
      local chunks = str.splits(line, "\t")
      local label = str.sub(chunks())
      if arr.includes(valid_labels, label) then
        chunks = it.drop(2, chunks)
        arr.push(pairs, {
          label = label,
          a = str.sub(chunks()),
          b = str.sub(chunks()),
        })
      end
    end
  end
  arr.shuffle(pairs)
  local train_end = math.floor(#pairs * args.train_test_ratio)
  write_pairs(pairs, args.output_train, 1, train_end)
  write_pairs(pairs, args.output_test, train_end + 1, #pairs)
end

return {
  snli_triplets = snli_triplets,
  snli_pairs = snli_pairs,
}
