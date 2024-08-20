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

nohup stdbuf -oL tbhss process snli \
  --inputs snli_1.0/snli_1.0_train.txt snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
  --train-test-ratio 0.9 \
  --output-train snli-triplets.train.txt \
  --output-test snli-triplets.test.txt \
    2>&1 >> log.txt & tail -f log.txt

# Small

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snl300-train \
  --file snli-small.train.txt \
  --clusters glove dbscan 2 0.645 5 \
  --dimensions 32 \
  --buckets 8 \
  --wavelength 512 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snl300-test \
  --file snli-small.test.txt \
  --model snl300-train \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snl300  \
  --triplets snl300-train snl300-test \
  --encoded-bits 256 \
  --clauses 8192 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --margin 0.15 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive true \
  --evaluate-every 1 \
  --epochs 100 \
    2>&1 >> log.txt & tail -f log.txt

# Medium

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snl65-train \
  --file snli-triplets.train.txt \
  --max-records 20000 \
  --clusters glove dbscan 2 0.645 5 \
  --dimensions 32 \
  --buckets 8 \
  --wavelength 512 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snl65-test \
  --file snl-triplets.test.txt \
  --max-records 2000 \
  --model snl65-train \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snl65  \
  --triplets snl65-train snl65-test \
  --encoded-bits 256 \
  --clauses 8192 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --margin 0.15 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive true \
  --evaluate-every 1 \
  --epochs 100 \
    2>&1 >> log.txt & tail -f log.txt
