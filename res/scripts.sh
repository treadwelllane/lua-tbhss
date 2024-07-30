nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load sentences \
  --cache tbhss.db \
  --name snli4.test \
  --file snli_1.0/snli_1.0_test.txt \
  --clusters glove 1024 1 3 0 false \
  --segments 1 \
  --dimensions 16 \
  --buckets 10 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli4.test  \
  --sentences snli4.test \
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
