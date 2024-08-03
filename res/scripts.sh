nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load train-sentences \
  --cache tbhss.db \
  --name snli0-train \
  --file snli_1.0/snli_1.0_train.txt \
  --clusters glove 1024 1 32 0 false \
  --segments 1 \
  --dimensions 64 \
  --buckets 20 \
  --saturation 1.2 \
  --length-normalization 0.75 \
  --max-records 10000 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-sentences \
  --cache tbhss.db \
  --name snli0-test \
  --file snli_1.0/snli_1.0_test.txt \
  --model snli0-train \
  --max-records 200 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli6.test  \
  --sentences snli0-train snli0-test \
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
