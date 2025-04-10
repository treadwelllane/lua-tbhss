local fun = require("santoku.functional")
local it = require("santoku.iter")
local arr = require("santoku.array")
return {
  modeler = {
    max_df           = it.ivals({ 0.95 }),
    min_df           = it.ivals({ 0.001 }),
    max_len          = it.ivals({ 20 }),
    min_len          = it.ivals({ 2 }),
    ngrams           = it.ivals({ 3 }),
    cgrams           = it.ivals({ 3 }),
    compress         = it.ivals({ true }),
    supervision      = it.ivals({ 0.25 }),
    hidden           = it.ivals({ 4096 }),
    iterations       = it.ivals({ 1000 }),
    eps              = it.ivals({ 0.0001 }),
    threads          = nil
  },
  classifier = {
    boost            = it.ivals({ true }),
    state            = it.ivals({ 8 }),
    evaluate_every   = it.ivals({ 1 }),
    iterations       = it.ivals({ 50 }),
    active           = it.ivals({ 0.25 }),
    clauses          = it.ivals({ 65536 }),
    target           = it.ivals({ 64, 128, 256, 512, 1024 }),
    specificity_low  = it.ivals({ 2 }),
    specificity_high = it.ivals({ 200 }),
    threads          = nil
  },
}
