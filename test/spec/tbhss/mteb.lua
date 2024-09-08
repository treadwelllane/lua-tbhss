local test = require("santoku.test")
local tbhss = require("tbhss")
local bm = require("santoku.bitmap")

local py = require("santoku.python")("libpython3.12.so")
local ptuple = py.builtin("tuple")
local pdict = py.builtin("dict")
local ptype = py.builtin("type")
local plen = py.builtin("len")
local mteb = py.import("mteb")
local np = py.import("numpy")

test("encode", function ()

  local encoder = tbhss.encoder(
    "test/res/snli5.db", "snli5",
    "test/res/snli5.bin")

  local model = ptype("", ptuple(), pdict(py.kwargs({
    encode = function (_, sentences)
      local encodings = {}
      for i = 1, plen(sentences) do
        local sentence = sentences[i - 1]
        local encoding = encoder.encode(sentence)
        encodings[#encodings + 1] =
          np.frombuffer(py.bytes(encoding), py.kwargs({
            dtype = np.uint8
          }))
      end
      return np.vstack(encodings)
    end,
    similarity_pairwise = function (_, as, bs)
      local scores = {}
      for i = 1, as.shape[0] do
        local a = bm.from_raw(py.slice(as, i, i + 1).tobytes(), encoder.bits)
        local b = bm.from_raw(py.slice(bs, i, i + 1).tobytes(), encoder.bits)
        scores[#scores + 1] = 1 - (bm.hamming(a, b) / encoder.bits)
      end
      return np.vstack(scores)
    end
  })))()

  local tasks = mteb.get_tasks(py.kwargs({
    tasks = { "STSBenchmark" }
    -- task_types = { "Retrieval" },
    -- languages = { "eng" }
  }))

  local eval = mteb.MTEB(py.kwargs({ tasks = tasks }))

  eval.run(model)

end)
