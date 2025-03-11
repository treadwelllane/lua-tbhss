nohup stdbuf -oL sh -c '

  set -e

  id=60

  epochs=10

  clusters=512
  clusters_step=*2
  clusters_stop=512

  while [ $(echo "$clusters <= $clusters_stop" | bc) -eq 1 ]; do

    tbhss load train-triplets \
      --cache tbhss.db \
      --name snli-$id-explore-train-$clusters \
      --file snli-triplets.train.txt \
      --max:
      --clusters glove dbscan 2 0.645 5 \
      --fingerprints simhash 4096 8 $clusters \
      --weighting bm25 4096 1.2 0.75

    tbhss load test-triplets \
      --cache tbhss.db \
      --name snli-$id-explore-test-$clusters \
      --file snli-triplets.test.txt \
      --max-records 500 \
      --model snli-$id-explore-train-$clusters

    margin=0.1
    margin_step=+0.05
    margin_stop=0.1

    while [ $(echo "$margin <= $margin_stop" | bc) -eq 1 ]; do

      bits=256
      bits_step=*2
      bits_stop=256

      while [ $(echo "$bits <= $bits_stop" | bc) -eq 1 ]; do

        spec=8
        spec_range=4
        spec_step=*2
        spec_stop=8

        while [ $(echo "$spec <= $spec_stop" | bc) -eq 1 ]; do

          specl=$(( spec - spec_range ))
          spech=$(( spec + spec_range ))

          [ $specl -lt 2 ] && specl=2

          echo Specificity $specl $spech
          echo Margin $margin
          echo Buckets $buckets
          echo Bits $bits

          tbhss create encoder \
            --cache tbhss.db \
            --name snli-$id-explore-$clusters-$margin-$bits-$spec-$spec_range \
            --triplets snli-$id-explore-train-$clusters snli-$id-explore-test-$clusters \
            --encoded-bits $bits \
            --clauses 4096 \
            --state-bits 8 \
            --threshold 36 \
            --specificity $specl $spech \
            --margin $margin \
            --loss-alpha 0.25 \
            --active-clause 0.85 \
            --boost-true-positive false \
            --evaluate-every 1 \
            --epochs $epochs

          spec=$(echo "$spec $spec_step" | bc)
        done
        bits=$(echo "$bits $bits_step" | bc)
      done
      margin=$(echo "$margin $margin_step" | bc)
    done
    clusters=$(echo "$clusters $clusters_step" | bc)
  done

' 2>&1 >> explore.txt & tail -f explore.txt
