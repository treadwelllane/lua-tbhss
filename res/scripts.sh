nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load sentences \
  --cache tbhss.db \
  --name snli36.test \
  --file snli_1.0/snli_1.0_test.txt \
  --clusters glove 256 1 3 0.5 false \
  --segments 4 \
  --dimensions 16 \
  --buckets 200 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli37.test  \
  --sentences snli35.test \
  --train-test-ratio 0.8 \
  --encoded-bits 512 \
  --clauses 1024 \
  --state-bits 8 \
  --threshold 256 \
  --specificity 2 200 \
  --margin 0.2 \
  --loss-alpha 0.5 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 100 \
    2>&1 > log.txt & tail -f log.txt
