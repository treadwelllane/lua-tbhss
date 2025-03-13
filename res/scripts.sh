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
  --name snli18-train \
  --file snli-triplets.train.txt \
  --max-records 20000 \
  --clusters glove dbscan 2 0.645 5 \
  --fingerprints simhash-positional 10000 32 10 \
  --weighting bm25 1.2 0.75 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snli18-test \
  --file snli-triplets.test.txt \
  --max-records 2000 \
  --model snli18-train \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create classifier \
  --cache tbhss.db \
  --name snli18  \
  --triplets snli18-train snli18-test \
  --clauses 4096 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 200 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli18  \
  --triplets snli18-train snli18-test \
  --encoded-bits 32 \
  --clauses 4096 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --margin 0.15 \
  --loss-alpha 0.25 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --epochs 200 \
    2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create autoencoder \
#   --cache tbhss.db \
#   --name snli18-compressor  \
#   --triplets snli18-train snli18-test \
#   --encoded-bits 128 \
#   --clauses 1024 \
#   --state-bits 8 \
#   --threshold 36 \
#   --specificity 4 12 \
#   --loss-alpha 0.5 \
#   --active-clause 0.85 \
#   --boost-true-positive false \
#   --evaluate-every 1 \
#   --epochs 200 \
#     2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss load compressed-triplets \
#   --cache tbhss.db \
#   --name snli18-train-compressed \
#   --triplets snli18-train \
#   --autoencoder snli18-compressor \
#     2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss load compressed-triplets \
#   --cache tbhss.db \
#   --name snli18-test-compressed \
#   --triplets snli18-test \
#   --autoencoder snli18-compressor \
#     2>&1 > log.txt & tail -f log.txt
