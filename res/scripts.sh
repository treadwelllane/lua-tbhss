nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --inputs snli_1.0/snli_1.0_train.txt snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
  --train-test-ratio 0.9 \
  --output-train snli-triplets.train.txt \
  --output-test snli-triplets.test.txt \
    2>&1 > log.txt & tail -f log.txt

# Small

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snli5-train \
  --file snli-triplets.train.txt \
  --max-records 20000 \
  --clusters glove k-medoids 256 1 \
  --fingerprints set-of-clusters \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snli5-test \
  --file snli-triplets.test.txt \
  --max-records 2000 \
  --model snli5-train \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli5  \
  --triplets snli5-train snli5-test \
  --encoded-bits 128 \
  --clauses 512 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --margin 0.15 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive true \
  --evaluate-every 1 \
  --epochs 50 \
    2>&1 > log.txt & tail -f log.txt

# Medium

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snli2-train \
  --file snli-triplets.train.txt \
  --max-records 20000 \
  --clusters glove dbscan 2 0.645 5 \
  --dimensions 32 \
  --segments 40 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snli2-test \
  --file snli-triplets.test.txt \
  --max-records 2000 \
  --model snli2-train \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli2  \
  --triplets snli2-train snli2-test \
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
