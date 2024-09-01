local str = require("santoku.string")
local varg = require("santoku.varg")
local fs = require("santoku.fs")
local it = require("santoku.iter")
local tbl = require("santoku.table")
local arr = require("santoku.array")

local function write_triplets (triplets, file)
  local tmp = {}
  for i = 1, #triplets do
    local t = triplets[i]
    arr.push(tmp, t.anchor, "\t", t.positive, "\t", t.negative, "\n")
  end
  fs.writefile(file, arr.concat(tmp))
end

local function add_pair (cache, a, b, label, is_majority)
  tbl.update(cache, a, label, function (ss)
    ss = ss or {}
    ss[b] = is_majority
    return ss
  end)
end

local function snli (args)

  local valid_labels = { "entailment", "contradiction", "neutral" }
  local cache = {}
  local label_counts = {}

  local majority = args.quality[1]
  local n_majorities = args.quality[2]

  for input in it.ivals(args.input) do
    for line in it.drop(1, fs.lines(input)) do
      local chunks = str.splits(line, "\t")
      local s, gs, ge = chunks()
      local gold_label = s and str.sub(s, gs, ge)
      if arr.includes(valid_labels, gold_label) then
        chunks = it.drop(4, chunks)
        local a = str.sub(chunks())
        local b = str.sub(chunks())
        add_pair(cache, a, b, gold_label, false)
        if args.include_entailment_as_premise then
          add_pair(cache, b, a, gold_label, false)
        end
        if majority > 0 then
          chunks = it.drop(2, chunks)
          label_counts.entailment = 0
          label_counts.contradiction = 0
          label_counts.neutral = 0
          for l in it.map(str.sub, it.take(5, chunks)) do
            if arr.includes(valid_labels, l) then
              label_counts[l] = label_counts[l] + 1
              if label_counts[l] >= 2 + majority then
                add_pair(cache, a, b, l, true)
                if args.include_entailment_as_premise then
                  add_pair(cache, b, a, l, true)
                end
                break
              end
            end
          end
        end
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
      for e, e_majority in pairs(ls.entailment) do
        for n, n_majority in it.chain(varg.map(it.pairs, ls.neutral or {}, ls.contradiction or {})) do
          if n_majorities <= 0 or
            (n_majorities == 1 and (e_majority or n_majority)) or
            (n_majorities >= 2 and (e_majority and n_majority))
          then
            triplets[#triplets + 1] = {
              anchor = a,
              positive = e,
              negative = n
            }
          end
        end
      end
    end

  end

  arr.shuffle(triplets)
  write_triplets(triplets, args.output)

end

return {
  snli = snli
}
