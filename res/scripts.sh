nohup stdbuf -oL tbhss create modeler \
  --cache tbhss.db \
  --name imdb-test1  \
  --max-df 0.95 \
  --min-df 0.005 \
  --max-len 20 \
  --min-len 20 \
  --hidden 2048 \
  --sentences imdb.train.sentences.txt \
  --iterations 1000 \
    2>&1 > log.txt & tail -f log.txt

nohup stdbuf -oL tbhss create classifier \
  --cache tbhss.db \
  --name imdb-test0  \
  --modeler imdb-test \
  --samples imdb.train.samples.txt imdb.test.samples.txt \
  --clauses 8192 \
  --state-bits 8 \
  --target 256 \
  --specificity 2 200 \
  --active-clause 0.85 \
  --boost-true-positive false \
  --evaluate-every 10 \
  --iterations 1000 \
    2>&1 > log.txt & tail -f log.txt
