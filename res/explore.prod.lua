local fun = require("santoku.functional")
local it = require("santoku.iter")
local arr = require("santoku.array")
return {
  modeler = {
    max_df           = it.ivals({ 0.95 }),
    min_df           = it.ivals({ 0.001 }),
    max_len          = it.ivals({ 20 }),
    min_len          = it.ivals({ 3 }),
    ngrams           = it.ivals({ 3 }),
    cgrams           = it.ivals({ 3 }),
    compress         = it.ivals({ true }),
    hidden           = it.ivals({ 512 }),
    iterations       = it.ivals({ 1000 }),
    eps              = it.ivals({ 0.00001 }),
    threads          = nil
  },
  classifier = {
    boost            = it.ivals({ true }),
    state            = it.ivals({ 8 }),
    evaluate_every   = it.ivals({ 1 }),
    iterations       = it.ivals({ 100 }),
    active           = it.ivals({ 0.85 }),
    clauses          = it.range(8192, 65536, fun.mul(2)),
    target           = it.range(32, 1024, fun.mul(2)),
    specificity_low  = it.ivals({ 2 }),
    specificity_high = it.ivals({ 200 }),
    threads          = nil
  },
}
