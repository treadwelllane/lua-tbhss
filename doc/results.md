# Dev

    Epoch 50    Time 17    Test 0.86  Train 1.00

    sys.execute({
      "lua", "bin/tbhss.lua", "process", "snli",
      "--inputs", "test/res/snli_1.0_dev.txt",
      "--train-test-ratio", "0.9",
      "--output-train", ".train.triplets.txt",
      "--output-test", ".test.triplets.txt",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "words",
      "--cache", db_file,
      "--name", "glove",
      "--file", "test/res/glove_snli_dev.train.txt",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "train-triplets",
      "--cache", db_file,
      "--name", "dev-train",
      "--file", ".train.triplets.txt",
      "--clusters", "glove", "1024", "1", "3", "0", "false",
      "--segments", "1",
      "--dimensions", "4",
      "--buckets", "20",
      "--saturation", "1.2",
      "--length-normalization", "0.75",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "test-triplets",
      "--cache", db_file,
      "--name", "dev-test",
      "--file", ".test.triplets.txt",
      "--model", "dev-train",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "create", "encoder",
      "--cache", db_file,
      "--name", "snli-dev",
      "--triplets", "dev-train", "dev-test",
      "--encoded-bits", "128",
      "--clauses", "2048",
      "--state-bits", "8",
      "--threshold", "32",
      "--specificity", "2", "200",
      "--margin", "0.1",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "100"
    })

# Dev + Test

    Epoch 100   Time 46    Test 0.86  Train 1.00

    nohup stdbuf -oL tbhss process snli \
      --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
      --train-test-ratio 0.9 \
      --output-train snli-small.train.txt \
      --output-test snli-small.test.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load train-triplets \
      --cache tbhss.db \
      --name snli-small.train \
      --file snli-small.train.txt \
      --clusters glove 1024 1 3 0 false \
      --segments 1 \
      --dimensions 32 \
      --buckets 20 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load test-triplets \
      --cache tbhss.db \
      --name snli-small.test \
      --file snli-small.test.txt \
      --model snli-small.train \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli-small  \
      --triplets snli-small.train snli-small.test \
      --encoded-bits 256 \
      --clauses 4096 \
      --state-bits 8 \
      --threshold 32 \
      --specificity 2 200 \
      --margin 0.1 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

# Dev + Test + Train

    TODO
