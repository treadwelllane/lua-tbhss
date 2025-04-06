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
    hidden           = it.ivals({ 32 }),
    iterations       = it.ivals({ 500 }),
    eps              = it.ivals({ 0.0001 }),
    threads          = it.ivals({ 6 }),
  },
  classifier = {
    boost            = it.ivals({ true }),
    state            = it.ivals({ 8 }),
    evaluate_every   = it.ivals({ 1 }),
    iterations       = it.ivals({ 20 }),
    active           = it.ivals({ 0.85 }),
    negatives        = it.ivals({ 0.25 }),
    replicas         = it.ivals({ 0 }),
    clauses          = it.ivals({ 32784 }),
    target           = it.ivals({ 256 }),
    specificity_low  = it.ivals({ 2 }),
    specificity_high = it.ivals({ 200 }),
    threads          = nil
  },
}
