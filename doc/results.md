# Small

    Epoch 42    Time 103   Test 0.93  Train 1.00

    nohup stdbuf -oL tbhss process snli \
      --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
      --train-test-ratio 0.9 \
      --output-train snli-small.train.txt \
      --output-test snli-small.test.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load train-triplets \
      --cache tbhss.db \
      --name snli70-train \
      --file snli-small.train.txt \
      --clusters glove dbscan 2 0.645 5 \
      --dimensions 32 \
      --buckets 10 \
      --wavelength 10000 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load test-triplets \
      --cache tbhss.db \
      --name snli70-test \
      --file snli-small.test.txt \
      --model snli70-train \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli70  \
      --triplets snli70-train snli70-test \
      --encoded-bits 256 \
      --clauses 8192 \
      --state-bits 8 \
      --threshold 36 \
      --specificity 4 12 \
      --margin 0.1 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

    Epoch 100   Time 89    Test 0.93  Train 1.00

    nohup stdbuf -oL tbhss process snli \
      --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
      --train-test-ratio 0.9 \
      --output-train snli-small.train.txt \
      --output-test snli-small.test.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load train-triplets \
      --cache tbhss.db \
      --name snli64-train \
      --file snli-small.train.txt \
      --clusters glove dbscan 2 0.645 5 \
      --dimensions 32 \
      --buckets 40 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load test-triplets \
      --cache tbhss.db \
      --name snli64-test \
      --file snli-small.test.txt \
      --model snli64-train \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli64  \
      --triplets snli64-train snli64-test \
      --encoded-bits 256 \
      --clauses 8192 \
      --state-bits 8 \
      --threshold 36 \
      --specificity 4 12 \
      --margin 0.1 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

    Epoch 100   Time 89    Test 0.93  Train 1.00

    nohup stdbuf -oL tbhss process snli \
      --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
      --train-test-ratio 0.9 \
      --output-train snli-small.train.txt \
      --output-test snli-small.test.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load train-triplets \
      --cache tbhss.db \
      --name snli51-train \
      --file snli-small.train.txt \
      --clusters glove 1024 1 3 0 false \
      --dimensions 32 \
      --buckets 40 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load test-triplets \
      --cache tbhss.db \
      --name snli51-test \
      --file snli-small.test.txt \
      --model snli51-train \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli51  \
      --triplets snli51-train snli51-test \
      --encoded-bits 256 \
      --clauses 8192 \
      --state-bits 8 \
      --threshold 36 \
      --specificity 4 12 \
      --margin 0.1 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

    Epoch 50    Time 100   Test 0.93  Train 1.00

    nohup stdbuf -oL tbhss process snli \
      --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
      --train-test-ratio 0.9 \
      --output-train snli-small.train.txt \
      --output-test snli-small.test.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load train-triplets \
      --cache tbhss.db \
      --name snli12-train \
      --file snli-small.train.txt \
      --clusters glove 1024 1 3 0 false \
      --dimensions 32 \
      --buckets 40 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load test-triplets \
      --cache tbhss.db \
      --name snli12-test \
      --file snli-small.test.txt \
      --model snli12-train \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli12  \
      --triplets snli12-train snli12-test \
      --encoded-bits 256 \
      --clauses 8192 \
      --state-bits 8 \
      --threshold 32 \
      --specificity 4 12 \
      --margin 0.1 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

    Epoch 42    Time 38    Test 0.90  Train 1.00

    nohup stdbuf -oL tbhss process snli \
      --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
      --train-test-ratio 0.9 \
      --output-train snli-small.train.txt \
      --output-test snli-small.test.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load train-triplets \
      --cache tbhss.db \
      --name snli7-train \
      --file snli-small.train.txt \
      --clusters glove 0.125 1 3 0 false \
      --dimensions 32 \
      --buckets 40 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load test-triplets \
      --cache tbhss.db \
      --name snli7-test \
      --file snli-small.test.txt \
      --model snli7-train \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli7  \
      --triplets snli7-train snli7-test \
      --encoded-bits 256 \
      --clauses 8192 \
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

    Epoch 100   Time 89    Test 0.92  Train 1.00

    nohup stdbuf -oL tbhss process snli \
      --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
      --train-test-ratio 0.9 \
      --output-train snli-small.train.txt \
      --output-test snli-small.test.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load train-triplets \
      --cache tbhss.db \
      --name snli-small.train7 \
      --file snli-small.train.txt \
      --clusters glove 1024 1 3 0 false \
      --dimensions 32 \
      --buckets 40 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load test-triplets \
      --cache tbhss.db \
      --name snli-small.test7 \
      --file snli-small.test.txt \
      --model snli-small.train7 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli-small7  \
      --triplets snli-small.train7 snli-small.test7 \
      --encoded-bits 256 \
      --clauses 8192 \
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

    Epoch 100   Time 91    Test 0.90  Train 1.00

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
      --name snli-small5  \
      --triplets snli-small.train snli-small.test \
      --encoded-bits 256 \
      --clauses 8192 \
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

# Dev

    Epoch 50    Time 15    Test 0.89  Train 1.00

    sys.execute({
      "lua", "bin/tbhss.lua", "process", "snli",
      "--inputs", "test/res/snli_1.0_dev.txt",
      "--train-test-ratio", "0.9",
      "--output-train", ".train.triplets.txt",
      "--output-test", ".test.triplets.txt",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "train-triplets",
      "--cache", db_file,
      "--name", "dev-train",
      "--file", ".train.triplets.txt",
      "--clusters", "glove", "dbscan", "2", "0.6", "5",
      "--dimensions", "4",
      "--buckets", "10",
      "--wavelength", "10000",
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
      "--threshold", "36",
      "--specificity", "4", "12",
      "--margin", "0.1",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "50"
    })

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
