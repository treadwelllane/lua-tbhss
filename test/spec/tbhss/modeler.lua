local test = require("santoku.test")
local modeler = require("tbhss.modeler")
local serialize = require("santoku.serialize")

test("get_expanded_tokens", function ()

  local ts = { 10, 20, 30, 40 }
  local ns = {
    [10] = {
      { cluster = 1, similarity = 1 },
      { cluster = 2, similarity = 1 },
      { cluster = 3, similarity = 1 },
    },
    [20] = {
      { cluster = 3, similarity = 1 },
      { cluster = 3, similarity = 1 },
      { cluster = 3, similarity = 1 },
    },
    [30] = {
      { cluster = 7, similarity = 1 },
      { cluster = 3, similarity = 1 },
      { cluster = 9, similarity = 1 },
    },
    [40] = {
      { cluster = 10, similarity = 1 },
      { cluster = 3, similarity = 1 },
      { cluster = 12, similarity = 1 },
    },
  }

  local tokens, positions, similarities =
    modeler.get_expanded_tokens(ts, ns)
  print(serialize(tokens, true))
  print(serialize(positions, true))
  print(serialize(similarities, true))

end)
