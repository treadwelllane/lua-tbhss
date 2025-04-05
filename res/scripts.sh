# Dev

stdbuf -eL -oL numactl --cpubind=0 --membind=0 tbhss explore imdb \
  --cache explore.db \
  --dirs test train \
  --cfg explore.opts.lua \
    2>&1 >> explore.txt & tail -f explore.txt

stdbuf -eL -oL tbhss process imdb \
  --dirs . \
  --train-test-ratio 0.95 \
  --samples \
      imdb-test.train.samples.txt \
      imdb-test.test.samples.txt \
  --sentences \
      imdb-test.train.sentences.txt \
      imdb-test.test.sentences.txt \
    2>&1 | tee -a log.txt

nohup stdbuf -eL -oL tbhss create modeler \
  --cache imdb-test.db \
  --name imdb-test13 \
  --max-df 0.95 \
  --min-df 0.001 \
  --max-len 20 \
  --min-len 2 \
  --ngrams 2 \
  --compress 128 500 0.001 \
  --sentences imdb-test.train.sentences.txt \
    2>&1 >> log.txt & tail -f log.txt

nohup stdbuf -eL -oL tbhss create classifier \
  --cache imdb-test.db \
  --name imdb-test13 \
  --modeler imdb-test13 \
  --samples \
      imdb-test.train.samples.txt \
      imdb-test.test.samples.txt \
  --clauses 4096 \
  --state-bits 8 \
  --target 256 \
  --specificity 2 200 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 1 \
  --iterations 500 \
    2>&1 >> log.txt & tail -f log.txt
