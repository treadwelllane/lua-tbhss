local tokenizer = require("tbhss.bpe")
local str = require("santoku.string")

local t = tokenizer.create({
  vocab = 512,
  wavelength = 4096,
  dimensions = 1,
  buckets = 1,
})

-- Courtesy of ChatGPT
local corpus = [[
  Byte by byte, it scans the lines
  Seeking pairs that most combine...
  Merges gather in surging waves,
  Turning letters to shorter enclaves.
  A shuffle of tokens, a swirl of text,
  Pairs unite, then vanish next...
  “at” entwines with “c” to purr
  Then “the” emerges, bright and sure....
  Spaces kept apart like walls,
  Guarding boundaries in lexical halls.
  No cross-word merges to slip astray—
  A single “ ” stands firm in the fray.
  Yet watch how frequency shapes the tide:
  “ca” and “at” fuse side by side,,,
  While lonely pairs fade from the heap,
  Yielding to the merges we keep...
  When all is done, the text transformed,
  The final subwords stand informed:
  No tokens left at higher stake—
  BPE rests from the merges it makes.
]]

t.train({ corpus = corpus })

local tokens = t.parse(corpus)
for i = 1, #tokens do
  str.printf("%d: '%s'\n", i, tokens[i])
end
