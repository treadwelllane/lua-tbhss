# Dev 2000

    Epoch 97    Time 2     Test 0.91  Train 0.98

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "sentences",
      "--cache", db_file,
      "--name", "snli-dev",
      "--file", "test/res/snli_1.0_dev.txt",
      "--clusters", "glove", "1024", "1", "3", "0", "false",
      "--segments", "1",
      "--dimensions", "4",
      "--buckets", "20",
      "--saturation", "1.2",
      "--length-normalization", "0.75",
      "--max-records", "2000",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "create", "encoder",
      "--cache", db_file,
      "--name", "snli-dev",
      "--sentences", "snli-dev",
      "--train-test-ratio", "0.8",
      "--encoded-bits", "128",
      "--clauses", "2048",
      "--state-bits", "8",
      "--threshold", "32",
      "--specificity", "2", "200",
      "--margin", "0.5",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "100"
    })

    Epoch 100   Time 3     Test 0.91  Train 0.97

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "sentences",
      "--cache", db_file,
      "--name", "snli-dev",
      "--file", "test/res/snli_1.0_dev.txt",
      "--clusters", "glove", "1024", "1", "3", "0", "false",
      "--segments", "1",
      "--dimensions", "4",
      "--buckets", "10",
      "--saturation", "1.2",
      "--length-normalization", "0.75",
      "--max-records", "2000",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "create", "encoder",
      "--cache", db_file,
      "--name", "snli-dev",
      "--sentences", "snli-dev",
      "--train-test-ratio", "0.8",
      "--encoded-bits", "128",
      "--clauses", "1024",
      "--state-bits", "8",
      "--threshold", "32",
      "--specificity", "2", "200",
      "--margin", "0.5",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "100"
    })

    Epoch 50    Time 6     Test 0.90  Train 0.98

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "sentences",
      "--cache", db_file,
      "--name", "snli-dev",
      "--file", os.getenv("SNLI") or "test/res/snli_1.0_dev.txt",
      "--clusters", "glove", "1024", "1", "3", "0.9", "false",
      "--segments", "1",
      "--dimensions", "4",
      "--buckets", "20",
      "--saturation", "1.2",
      "--length-normalization", "0.75",
      "--max-records", "2000",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "create", "encoder",
      "--cache", db_file,
      "--name", "snli-dev",
      "--sentences", "snli-dev",
      "--train-test-ratio", "0.8",
      "--encoded-bits", "128",
      "--clauses", "1024",
      "--state-bits", "8",
      "--threshold", "32",
      "--specificity", "2", "200",
      "--margin", "0.5",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "50"
    })

    Epoch 50    Time 4     Test 0.86  Train 0.98

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "sentences",
      "--cache", db_file,
      "--name", "snli-dev",
      "--file", os.getenv("SNLI") or "test/res/snli_1.0_dev.txt",
      "--clusters", "glove", "1024", "1", "3", "0.9", "false",
      "--segments", "1",
      "--dimensions", "4",
      "--buckets", "20",
      "--saturation", "1.2",
      "--length-normalization", "0.75",
      "--max-records", "2000",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "create", "encoder",
      "--cache", db_file,
      "--name", "snli-dev",
      "--sentences", "snli-dev",
      "--train-test-ratio", "0.8",
      "--encoded-bits", "128",
      "--clauses", "1024",
      "--state-bits", "8",
      "--threshold", "32",
      "--specificity", "2", "200",
      "--margin", "0.4",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "50"
    })

    Epoch 50    Time 2     Test 0.85  Train 0.98

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "words",
      "--cache", db_file,
      "--name", "glove",
      "--file", os.getenv("GLOVE") or "test/res/glove.txt",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "sentences",
      "--cache", db_file,
      "--name", "snli-dev",
      "--file", os.getenv("SNLI") or "test/res/snli_1.0_dev.txt",
      "--clusters", "glove", "1024", "1", "3", "0.9", "false",
      "--segments", "1",
      "--dimensions", "4",
      "--buckets", "20",
      "--saturation", "1.2",
      "--length-normalization", "0.75",
      "--max-records", "2000",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "create", "encoder",
      "--cache", db_file,
      "--name", "snli-dev",
      "--sentences", "snli-dev",
      "--train-test-ratio", "0.8",
      "--encoded-bits", "128",
      "--clauses", "1024",
      "--state-bits", "8",
      "--threshold", "32",
      "--specificity", "2", "200",
      "--margin", "0.3",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "50"
    })

    Epoch 50    Time 6     Test 0.84  Train 0.98

    sys.execute({
      "lua", "bin/tbhss.lua", "load", "sentences",
      "--cache", db_file,
      "--name", "snli-dev",
      "--file", os.getenv("SNLI") or "test/res/snli_1.0_dev.txt",
      "--clusters", "glove", "1024", "1", "3", "0.9", "false",
      "--segments", "1",
      "--dimensions", "4",
      "--buckets", "20",
      "--saturation", "1.2",
      "--length-normalization", "0.75",
      "--max-records", "2000",
    })

    sys.execute({
      "lua", "bin/tbhss.lua", "create", "encoder",
      "--cache", db_file,
      "--name", "snli-dev",
      "--sentences", "snli-dev",
      "--train-test-ratio", "0.8",
      "--encoded-bits", "128",
      "--clauses", "1024",
      "--state-bits", "8",
      "--threshold", "32",
      "--specificity", "2", "200",
      "--margin", "0.6",
      "--loss-alpha", "0.25",
      "--active-clause", "0.85",
      "--boost-true-positive", "true",
      "--evaluate-every", "1",
      "--epochs", "50"
    })

# Test

    Epoch 100   Time 31    Test 0.89  Train 0.98

    nohup stdbuf -oL tbhss load sentences \
      --cache tbhss.db \
      --name snli5.test \
      --file snli_1.0/snli_1.0_test.txt \
      --clusters glove 1024 1 3 0 false \
      --segments 1 \
      --dimensions 16 \
      --buckets 20 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli5.test  \
      --sentences snli5.test \
      --train-test-ratio 0.8 \
      --encoded-bits 256 \
      --clauses 4096 \
      --state-bits 8 \
      --threshold 32 \
      --specificity 2 200 \
      --margin 0.5 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

    Epoch 100   Time 24    Test 0.88  Train 0.99

    nohup stdbuf -oL tbhss load sentences \
      --cache tbhss.db \
      --name snli3.test \
      --file snli_1.0/snli_1.0_test.txt \
      --clusters glove 4096 1 3 0 false \
      --segments 1 \
      --dimensions 16 \
      --buckets 10 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli3.test  \
      --sentences snli3.test \
      --train-test-ratio 0.8 \
      --encoded-bits 256 \
      --clauses 4096 \
      --state-bits 8 \
      --threshold 32 \
      --specificity 2 200 \
      --margin 0.5 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

    Epoch 100   Time 24    Test 0.88  Train 0.99

    nohup stdbuf -oL tbhss load sentences \
      --cache tbhss.db \
      --name snli2.test \
      --file snli_1.0/snli_1.0_test.txt \
      --clusters glove 4096 1 3 0 false \
      --segments 1 \
      --dimensions 16 \
      --buckets 20 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli2.test  \
      --sentences snli2.test \
      --train-test-ratio 0.8 \
      --encoded-bits 256 \
      --clauses 4096 \
      --state-bits 8 \
      --threshold 32 \
      --specificity 2 200 \
      --margin 0.5 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

    Epoch 100   Time 13    Test 0.81  Train 0.98

    nohup stdbuf -oL tbhss load words \
      --cache tbhss.db \
      --name glove \
      --file glove.6B.300d.txt \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss load sentences \
      --cache tbhss.db \
      --name snli45.test \
      --file snli_1.0/snli_1.0_test.txt \
      --clusters glove 4096 1 3 0.9 false \
      --segments 1 \
      --dimensions 8 \
      --buckets 20 \
      --saturation 1.2 \
      --length-normalization 0.75 \
        2>&1 > log.txt & tail -f log.txt

    nohup stdbuf -oL tbhss create encoder \
      --cache tbhss.db \
      --name snli45.test  \
      --sentences snli45.test \
      --train-test-ratio 0.8 \
      --encoded-bits 256 \
      --clauses 2048 \
      --state-bits 8 \
      --threshold 32 \
      --specificity 2 200 \
      --margin 0.3 \
      --loss-alpha 0.25 \
      --active-clause 0.85 \
      --boost-true-positive true \
      --evaluate-every 1 \
      --epochs 100 \
        2>&1 > log.txt & tail -f log.txt

# Train

    TODO
