local tokenizer = require("tbhss.tokenizer")
local it = require("santoku.iter")
local str = require("santoku.string")

local t = tokenizer.create({
  max_df = 0.70,
  wavelength = 4096,
  dimensions = 1,
  buckets = 1,
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
print("Features", t.train({ corpus = corpus }))

for i = 1, #corpus do
  local tokens = t.parse(corpus[i])
  str.printf("%d: ", i);
  for j = 1, #tokens do
    str.printf("%s, ", tokens[j])
  end
  str.printf("\n")
end
