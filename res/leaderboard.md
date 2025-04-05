# IMDB (all 50k, 95% train)

    Epoch 254    245.5089     17.04s   4435.48s
    Epoch 461    Time   16.35  11168.06   Test 0.82  Train 1.00
    Epoch 500    Time   16.47  11802.95   Test 0.81  Train 0.99

    {
      ["modeler"] = {
        ["max_df"] = 0.95,
        ["ngrams"] = 3,
        ["min_df"] = 0.001,
        ["max_len"] = 20,
        ["cgrams"] = 3,
        ["iterations"] = 500,
        ["eps"] = 0.0001,
        ["min_len"] = 3
      },
      ["classifier"] = {
        ["evaluate_every"] = 1,
        ["boost_true_positive"] = true,
        ["iterations"] = 500
      },
      ["params"] = {
        ["target"] = 64,
        ["clauses"] = 65536,
        ["hidden"] = 512,
        ["specificity"] = {
          2,
          200
        }
      }
    }

    Epoch 494    243.2439     16.41s   8767.66s
    Epoch 50     Time   54.90  2708.87   Test 0.80  Train 0.92

    {
      ["modeler"] = {
        ["max_df"] = 0.95,
        ["ngrams"] = 3,
        ["min_df"] = 0.001,
        ["max_len"] = 20,
        ["cgrams"] = 3,
        ["iterations"] = 500,
        ["eps"] = 0.0001,
        ["min_len"] = 3
      },
      ["classifier"] = {
        ["evaluate_every"] = 1,
        ["boost_true_positive"] = true,
        ["iterations"] = 50
      },
      ["params"] = {
        ["target"] = 512,
        ["clauses"] = 65536,
        ["hidden"] = 512,
        ["specificity"] = {
          2,
          200
        }
      }
    }
