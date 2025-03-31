local tokenizer = require("tbhss.tokenizer")
local it = require("santoku.iter")
local str = require("santoku.string")

local t = tokenizer.create({
  max_df = 0.7,
  min_df = 0.1,
  min_len = 3,
  max_len = 20,
  ngrams = 2
})

-- Courtesy of ChatGPT
local corpus = it.collect(str.gmatch([[
      The quick brown fox jumped over the lazy dog.
      Sphinx of black quartz, judge my vow.
  XXX Pack my box with five dozen liquor jugs.
  XXX How vexingly quick daft zebras jump!
  XXX Quick zephyrs blow, vexing daft Jim.
  XXX Waltz, bad nymph, for quick jigs vex.
  XXX Glib jocks quiz nymph to vex dwarf.
  XXX The five boxing wizards jump quickly.
  XXX Five quacking zephyrs jolt my wax bed.
  XXX Crazy Fredrick bought many very exquisite opal jewels.
]], "[^\n]+"))

print("Docs", #corpus)

t.train({ corpus = corpus })
t.finalize()

print("Features", t.features())

t = tokenizer.load(t.persist(), nil, true)

for i = 1, #corpus do
  local tokens = t.parse(corpus[i])
  str.printf("%d: ", i);
  for j = 1, #tokens do
    str.printf("%s", tokens[j])
    if j < #tokens then
      str.printf(", ")
    end
  end
  str.printf("\n")
end
