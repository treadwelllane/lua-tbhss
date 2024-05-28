nohup stdbuf -oL tbhss load words \
  --cache tbhss.db \
  --name glove.6B.300d \
  --file glove.6B.300d.txt 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss load sentences \
  --cache tbhss.db \
  --name snli_1.0.dev \
  --file snli_1.0/snli_1.0_dev.txt 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create clusters \
  --cache tbhss.db \
  --name glove.6B.300d.128 \
  --clusters 128 \
  --filter-words snli_1.0.dev \
  --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create bitmaps clustered \
  --cache tbhss.db \
  --name glove.6B.300d.128.3.3.00 \
  --clusters glove.6B.300d.128 \
  --min-set 3 \
  --max-set 3 \
  --min-similarity 0 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create bitmaps clustered \
  --cache tbhss.db \
  --name glove.6B.300d.128.8.8.00 \
  --clusters glove.6B.300d.128 \
  --min-set 8 \
  --max-set 8 \
  --min-similarity 0.0 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder recurrent \
  --cache tbhss.db \
  --name glove \
  --bitmaps glove.6B.300d.128.3.3.00  \
  --sentences snli_1.0.dev \
  --max-words 20 \
  --positional-bits 16 \
  --encoded-bits 256 \
  --train-test-ratio 0.5 \
  --clauses 8192 \
  --state-bits 8 \
  --threshold 128 \
  --margin 0.1 \
  --loss-alpha 1.25 \
  --specificity 15 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --max-records 2000 \
  --evaluate-every 1 \
  --epochs 1000 2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create encoder windowed \
  --cache tbhss.db \
  --name glove \
  --bitmaps glove.6B.300d.128.8.8.00  \
  --sentences snli_1.0.dev \
  --encoded-bits 128 \
  --train-test-ratio 0.5 \
  --clauses 512 \
  --state-bits 8 \
  --threshold 256 \
  --margin 0.1 \
  --loss-alpha 1 \
  --specificity 2 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --max-records 1000 \
  --evaluate-every 1 \
  --epochs 1000 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss load words \
#   --cache tbhss.db \
#   --name glove.6B.50d \
#   --file glove.6B.50d.txt 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create clusters \
#   --cache tbhss.db \
#   --name glove.6B.300d.256 \
#   --clusters 256 \
#   --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create bitmaps clustered \
#   --cache tbhss.db \
#   --name glove.6B.300d.128.1.16.00 \
#   --clusters glove.6B.300d.128 \
#   --min-set 1 \
#   --max-set 16 \
#   --min-similarity 0.0 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create bitmaps clustered \
#   --cache tbhss.db \
#   --name glove.6B.300d.256.1.32.00 \
#   --clusters glove.6B.300d.256 \
#   --min-set 1 \
#   --max-set 32 \
#   --min-similarity 0.00 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create bitmaps thresholded \
#   --cache tbhss.db \
#   --name glove.6B.50d.4 \
#   --threshold-levels 4 \
#   --words glove.6B.50d 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create encoder recurrent \
#   --cache tbhss.db \
#   --name glove \
#   --bitmaps glove.6B.50d.4  \
#   --sentences snli_1.0.dev \
#   --encoded-bits 512 \
#   --train-test-ratio 0.5 \
#   --clauses 500 \
#   --state-bits 8 \
#   --threshold 200 \
#   --margin 0.1 \
#   --loss-alpha 0.8 \
#   --specificity 2.4 \
#   --active-clause 0.85 \
#   --boost-true-positive true \
#   --evaluate-every 1 \
#   --max-records 500 \
#   --epochs 1000 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create encoder recurrent \
#   --cache tbhss.db \
#   --name glove \
#   --bitmaps glove.6B.300d.128.1.16.00  \
#   --sentences snli_1.0.dev \
#   --encoded-bits 128 \
#   --train-test-ratio 0.5 \
#   --clauses 500 \
#   --state-bits 8 \
#   --threshold 200 \
#   --margin 0.1 \
#   --loss-alpha 1 \
#   --specificity 2.4 \
#   --active-clause 0.85 \
#   --boost-true-positive true \
#   --evaluate-every 1 \
#   --max-records 500 \
#   --epochs 1000 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create encoder recurrent \
#   --cache tbhss.db \
#   --name glove \
#   --bitmaps glove.6B.300d.256.1.32.00  \
#   --sentences snli_1.0.dev \
#   --encoded-bits 256 \
#   --train-test-ratio 0.5 \
#   --clauses 80 \
#   --state-bits 8 \
#   --threshold 200 \
#   --margin 0.05 \
#   --loss-alpha 0.4 \
#   --specificity 5 \
#   --active-clause 0.5 \
#   --boost-true-positive false \
#   --evaluate-every 1 \
#   --max-records 200 \
#   --epochs 1000 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create clusters \
#   --cache tbhss.db \
#   --name glove.6B.300d.64 \
#   --clusters 64 \
#   --words glove.6B.300d 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create bitmaps clustered \
#   --cache tbhss.db \
#   --name glove.6B.300d.64.1.16.05 \
#   --clusters glove.6B.300d.64 \
#   --min-set 1 \
#   --max-set 16 \
#   --min-similarity 0.5 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create bitmaps encoded \
#   --cache tbhss.db \
#   --name glove.6B.300d.encoded.32 \
#   --words glove.6B.300d \
#   --encoded-bits 32 \
#   --threshold-levels 10 \
#   --similarity-positive 0.7 \
#   --similarity-negative 0.4 \
#   --threshold-levels 10 \
#   --train-test-ratio 0.8 \
#   --clauses 80 \
#   --state-bits 8 \
#   --threshold 200 \
#   --margin 0.1 \
#   --loss-alpha 1 \
#   --specificity 2.4 \
#   --active-clause 0.85 \
#   --boost-true-positive false \
#   --evaluate-every 1 \
#   --max-records 10000 \
#   --epochs 1000 2>&1 > log.txt & tail -f log.txt

# nohup stdbuf -oL tbhss create encoder windowed \
#   --cache tbhss.db \
#   --name glove \
#   --bitmaps glove.6B.300d.256.1.32.02  \
#   --sentences snli_1.0.dev \
#   --window-size 40 \
#   --encoded-bits 256 \
#   --train-test-ratio 0.8 \
#   --clauses 2000 \
#   --state-bits 8 \
#   --threshold 200 \
#   --margin 0.1 \
#   --loss-alpha 1 \
#   --specificity 2.4 \
#   --active-clause 0.85 \
#   --boost-true-positive false \
#   --evaluate-every 1 \
#   --epochs 1000 2>&1 > log.txt & tail -f log.txt
