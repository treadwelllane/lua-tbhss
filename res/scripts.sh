nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove.6B.300d \
  --file glove.6B.300d.txt 2>&1 > log.txt & tail -f log.txt

## Test

nohup stdbuf -oL tbhss load sentences \
  --cache tbhss.db \
  --name snli_1.0.test \
  --file snli_1.0/snli_1.0_test.txt 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create clusters \
  --cache tbhss.db \
  --name glove.6B.300d.64.test \
  --clusters 64 \
  --filter-words snli_1.0.test \
  --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create clusters \
  --cache tbhss.db \
  --name glove.6B.300d.256.test \
  --clusters 256 \
  --filter-words snli_1.0.test \
  --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create clusters \
  --cache tbhss.db \
  --name glove.6B.300d.512.test \
  --clusters 512 \
  --filter-words snli_1.0.test \
  --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name glove.6B.300d.256.test.1.8.00.8.256 \
  --bitmaps glove.6B.300d.256.test.1.8.00 \
  --sentences snli_1.0.test \
  --segments 1 \
  --encoded-bits 256 \
  --train-test-ratio 0.5 \
  --clauses 256 \
  --state-bits 8 \
  --threshold 256 \
  --specificity 35 45 \
  --margin 0.1 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 100 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name glove.6B.300d.64.test.1.4.00.8.256 \
  --bitmaps glove.6B.300d.64.test.1.4.00 \
  --sentences snli_1.0.test \
  --segments 8 \
  --encoded-bits 256 \
  --train-test-ratio 0.8 \
  --clauses 2048 \
  --state-bits 8 \
  --threshold 256 \
  --specificity 35 45 \
  --margin 0.1 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 1000 2>&1 > log.txt & tail -f log.txt

## Train

nohup stdbuf -oL tbhss load sentences \
  --cache tbhss.db \
  --name snli_1.0.train \
  --file snli_1.0/snli_1.0_train.txt 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create clusters \
  --cache tbhss.db \
  --name glove.6B.300d.256.train \
  --clusters 256 \
  --filter-words snli_1.0.train \
  --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name glove.6B.300d.256.train.1.8.00.8.256 \
  --bitmaps glove.6B.300d.256.train.1.8.00 \
  --sentences snli_1.0.train snli_1.0.test \
  --segments 8 \
  --encoded-bits 256 \
  --train-test-ratio 0.5 \
  --clauses 512 \
  --state-bits 8 \
  --threshold 256 \
  --specificity 35 45 \
  --margin 0.1 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 100 2>&1 > log.txt & tail -f log.txt

## Hash

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name glove.6B.300d.512.test.hashed.8.256 \
  --clusters glove.6B.300d.512.test 1 8 0 \
  --sentences snli_1.0.test \
  --segments 8 \
  --include-raw true \
  --position-dimensions 8 \
  --position-buckets 100 \
  --encoded-bits 256 \
  --train-test-ratio 0.8 \
  --clauses 2048 \
  --state-bits 8 \
  --threshold 256 \
  --specificity 50 70 \
  --margin 0.1 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 1000 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name glove.6B.300d.hashed.8.256 \
  --sentences snli_1.0.train snli_1.0.test \
  --segments 8 \
  --encoded-bits 256 \
  --train-test-ratio 0.5 \
  --clauses 512 \
  --state-bits 8 \
  --threshold 256 \
  --specificity 2 200 \
  --margin 0.1 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 100 2>&1 > log.txt & tail -f log.txt

