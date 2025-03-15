nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli-pairs \
  --inputs snli_1.0/snli_1.0_dev.txt \
  --train-test-ratio 0.9 \
  --output-train snli-pairs.train.txt \
  --output-test snli-pairs.test.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli-pairs \
  --inputs snli_1.0/snli_1.0_train.txt snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_dev.txt \
  --train-test-ratio 0.9 \
  --output-train snli-pairs.train.txt \
  --output-test snli-pairs.test.txt \
    2>&1 > log.txt & tail -f log.txt

# Small

nohup stdbuf -oL tbhss load train-pairs \
  --cache tbhss.db \
  --name snli35-train \
  --file snli-pairs.train.txt \
  --max-records 10000 \
  --clusters glove k-medoids 32 32 \
  --fingerprints hashed 4096 32 8 1024 \
  --include-pos --pos-ancestors 1 \
  --weighting bm25 1.2 0.75 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-pairs \
  --cache tbhss.db \
  --name snli35-test \
  --file snli-pairs.test.txt \
  --max-records 1000 \
  --model snli35-train \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create classifier \
  --cache tbhss.db \
  --name snli35  \
  --pairs snli35-train snli35-test \
  --clauses 512 \
  --state-bits 8 \
  --threshold 32 \
  --specificity 28 32 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 10 \
  --epochs 400 \
    2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create encoder \
#   --cache tbhss.db \
#   --name snli18  \
#   --triplets snli18-train snli18-test \
#   --encoded-bits 32 \
#   --clauses 4096 \
#   --state-bits 8 \
#   --threshold 36 \
#   --specificity 4 12 \
#   --margin 0.15 \
#   --loss-alpha 0.25 \
#   --active-clause 0.85 \
#   --boost-true-positive false \
#   --evaluate-every 1 \
#   --epochs 200 \
#     2>&1 > log.txt & tail -f log.txt

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
