nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove.6B.300d \
  --file glove.6B.300d.txt 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load sentences \
  --cache tbhss.db \
  --name snli_1.0.train \
  --file snli_1.0/snli_1.0_train.txt 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load sentences \
  --cache tbhss.db \
  --name snli_1.0.test \
  --file snli_1.0/snli_1.0_test.txt 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create clusters \
  --cache tbhss.db \
  --name glove.6B.300d.128.train \
  --clusters 128 \
  --filter-words snli_1.0.train \
  --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create clusters \
  --cache tbhss.db \
  --name glove.6B.300d.256.test \
  --clusters 256 \
  --filter-words snli_1.0.test \
  --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create bitmaps clustered \
  --cache tbhss.db \
  --name glove.6B.300d.128.train.3.3.00 \
  --clusters glove.6B.300d.128.train \
  --min-set 3 \
  --max-set 3 \
  --min-similarity 0.00 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create bitmaps clustered \
  --cache tbhss.db \
  --name glove.6B.300d.256.test.1.8.00 \
  --clusters glove.6B.300d.256.test \
  --min-set 1 \
  --max-set 8 \
  --min-similarity 0.00 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name glove \
  --bitmaps glove.6B.300d.128.train.3.3.00  \
  --sentences snli_1.0.train \
  --encoded-bits 128 \
  --train-test-ratio 0.5 \
  --clauses 80 \
  --state-bits 8 \
  --threshold 256 \
  --margin 0.1 \
  --loss-alpha 1 \
  --spec-min 2 \
  --spec-max 40 \
  --spec-alpha 1 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 5 \
  --epochs 100 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name glove \
  --bitmaps glove.6B.300d.256.test.1.8.00  \
  --sentences snli_1.0.test \
  --encoded-bits 256 \
  --train-test-ratio 0.5 \
  --clauses 1024 \
  --state-bits 8 \
  --threshold 256 \
  --margin 0.05 \
  --loss-alpha 2 \
  --spec-min 2 \
  --spec-max 60 \
  --spec-alpha 1 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 100 2>&1 > log.txt & tail -f log.txt
