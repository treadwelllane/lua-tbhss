nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove0 \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_dev.txt \
  --output snli.triplets.1.2.dev.txt \
  --quality 1 2 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_test.txt \
  --output snli.triplets.1.2.test.txt \
  --quality 1 2 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_train.txt \
  --output snli.triplets.1.2.train.txt \
  --quality 1 2 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_dev.txt snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_train.txt \
  --output snli.triplets.1.2.all.txt \
  --quality 1 2 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snli1-train \
  --file snli.triplets.1.2.all.train.txt \
  --clusters glove0 dbscan 2 0.645 5 \
  --merge false \
  --dimensions 32 \
  --buckets 8 \
  --wavelength 200 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snli1-dev \
  --file snli.triplets.1.2.all.dev.txt \
  --model snli1-train \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli6 \
  --persist-file snli6.bin \
  --persist-state false \
  --triplets snli1-train snli1-dev \
  --encoded-bits 256 \
  --clauses 8192 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --margin 0.15 \
  --loss-alpha 0.125 \
  --active-clause 0.85 \
  --boost-true-positive true \
  --evaluate-every 1 \
  --epochs 100 \
    2>&1 >> log.txt & tail -f log.txt
