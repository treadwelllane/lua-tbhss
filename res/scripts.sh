nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove \
  --file glove.6B.300d.txt \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_dev.txt \
  --output snli.triplets.1.1.dev.txt \
  --quality 1 1 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_test.txt \
  --output snli.triplets.1.1.test.txt \
  --quality 1 1 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_train.txt \
  --output snli.triplets.1.1.train.txt \
  --quality 1 1 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss process snli \
  --input snli_1.0/snli_1.0_dev.txt snli_1.0/snli_1.0_test.txt snli_1.0/snli_1.0_train.txt \
  --output snli.triplets.3.2.all.txt \
  --quality 1 2 \
    2>&1 > log.txt & tail -f log.txt

# Small

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snl405-train \
  --file snli.triplets.1.2.all.train.txt \
  --clusters glove dbscan 2 0.645 5 \
  --merge false \
  --dimensions 32 \
  --buckets 8 \
  --wavelength 200 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snl405-test \
  --file snli.triplets.1.2.all.dev.txt \
  --model snl405-train \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli405  \
  --triplets snl405-train snl405-test \
  --encoded-bits 256 \
  --clauses 8192 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --margin 0.15 \
  --loss-alpha 0 \
  --active-clause 0.85 \
  --boost-true-positive true \
  --evaluate-every 1 \
  --epochs 100 \
    2>&1 >> log.txt & tail -f log.txt

# Medium

nohup stdbuf -oL tbhss load train-triplets \
  --cache tbhss.db \
  --name snl505-train \
  --file snli.triplets.1.1.train.txt \
  --clusters glove dbscan 2 0.645 5 \
  --merge false \
  --dimensions 32 \
  --buckets 8 \
  --wavelength 200 \
  --saturation 1.2 \
  --length-normalization 0.75 \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load test-triplets \
  --cache tbhss.db \
  --name snl505-test \
  --file snli.triplets.1.1.dev.txt \
  --model snl505-train \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder \
  --cache tbhss.db \
  --name snli505  \
  --triplets snli505-train snli505-test \
  --encoded-bits 256 \
  --clauses 8192 \
  --state-bits 8 \
  --threshold 36 \
  --specificity 4 12 \
  --margin 0.15 \
  --loss-alpha 0 \
  --active-clause 0.85 \
  --boost-true-positive true \
  --evaluate-every 1 \
  --epochs 100 \
    2>&1 >> log.txt & tail -f log.txt
