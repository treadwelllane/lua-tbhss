local serialize = require("santoku.serialize")
local rand = require("santoku.random")
local arr = require("santoku.array")
local fs = require("santoku.fs")

local modeler = require("tbhss.modeler")
local classifier = require("tbhss.classifier")
local process = require("tbhss.preprocess")

return function (db, args)

  local cfg = fs.runfile(args.cfg)

  local function sample (o_modeler, o_classifier)

    local k_modeler = o_modeler.k
    local k_classifier = o_classifier.k

    local name_modeler = "explore " .. k_modeler
    local name_classifier = "explore " .. k_classifier

    local has_data = fs.exists(name_modeler .. ".train.sentences.txt")
    local has_modeler = db.modeler_exists(name_modeler)
    local has_classifier = db.classifier_exists(name_classifier)

    if not has_modeler or not has_classifier then
      print()
      print(name_modeler)
      print(name_classifier)
      print()
      print(serialize({
        modeler = o_modeler,
        classifier = o_classifier,
      }))
      print()
    end

    local dir = fs.dirname(db.file)

    if not has_data then
      process.imdb({
        dirs = args.dirs,
        train_test_ratio = 0.95,
        sentences = {
          fs.join(dir, name_modeler .. ".train.sentences.txt"),
          fs.join(dir, name_modeler .. ".test.sentences.txt")
        },
        samples = {
          fs.join(dir, name_modeler .. ".train.samples.txt"),
          fs.join(dir, name_modeler .. ".test.samples.txt")
        },
        max = args.max
      })
    end

    if not has_modeler then
      modeler.create(db, {
        name = name_modeler,
        max_df = o_modeler.max_df,
        min_df = o_modeler.min_df,
        max_len = o_modeler.max_len,
        min_len = o_modeler.min_len,
        ngrams = o_modeler.ngrams,
        cgrams = o_modeler.cgrams,
        compress = o_modeler.compress,
        hidden = o_modeler.hidden,
        sentences = fs.join(dir, name_modeler .. ".train.sentences.txt"),
        iterations = o_modeler.iterations,
        threads = o_modeler.threads,
        eps = o_modeler.eps,
      })
    end

    if not has_classifier then
      classifier.create(db, {
        name = name_classifier,
        modeler = name_modeler,
        clauses = o_classifier.clauses,
        state = o_classifier.state,
        target = o_classifier.target,
        active = o_classifier.active,
        boost = o_classifier.boost,
        specificity_low = o_classifier.specificity_low,
        specificity_high = o_classifier.specificity_high,
        threads = o_classifier.threads,
        samples = {
          fs.join(dir, name_modeler .. ".train.samples.txt"),
          fs.join(dir, name_modeler .. ".test.samples.txt")
        },
        evaluate_every = o_classifier.evaluate_every,
        iterations = o_classifier.iterations,
      })
    end

  end

  local ms, cs = {}, {}

  rand.options(cfg.modeler, function (opts, n, k)
    opts.k = k
    arr.push(ms, opts)
    return n < 100
  end, true)

  rand.options(cfg.classifier, function (opts, n, k)
    opts.k = k
    if opts.target < opts.clauses / 2 then
      arr.push(cs, opts)
    end
    return n < 100
  end, true)

  for i = 1, #ms do
    if not ms[i] or not cs[i] then
      break
    end
    sample(ms[i], cs[i])
  end

end
