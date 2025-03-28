local tokenizer = require("tbhss.bpe")
local str = require("santoku.string")

local t = tokenizer.create({
  vocab = 150,
  wavelength = 4096,
  dimensions = 1,
  buckets = 1,
})

-- Courtesy of ChatGPT
local corpus = [[
  The quick brown fox jumped over the lazy dog.
  Sphinx of black quartz, judge my vow.
  Pack my box with five dozen liquor jugs.
  How vexingly quick daft zebras jump!
  Quick zephyrs blow, vexing daft Jim.
  Waltz, bad nymph, for quick jigs vex.
  Glib jocks quiz nymph to vex dwarf.
  Two driven jocks help fax my big quiz.
  The five boxing wizards jump quickly.
  Five quacking zephyrs jolt my wax bed.
  Crazy Fredrick bought many very exquisite opal jewels.
]]

t.train({ corpus = corpus })

local tokens = t.parse(corpus)
for i = 1, #tokens do
  str.printf("%d: '%s'\n", i, tokens[i])
end
