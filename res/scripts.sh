nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --inputs snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
  --train-test-ratio 0.9 \
  --output-train snli-small.train.txt \
  --output-test snli-small.test.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snli-small.train10 \
  --file snli-small.train.txt \
  --clusters glove 1024 1 3 0 false \
  --dimensions 32 \
  --buckets 40 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snli-small.test10 \
  --file snli-small.test.txt \
  --model snli-small.train10 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli-small10  \
  --triplets snli-small.train10 snli-small.test10 \
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
