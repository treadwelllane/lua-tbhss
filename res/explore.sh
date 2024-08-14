nohup stdbuf -oL sh -c '

  set -e

  id=24

  clusters=1
  clusters_step=1
  clusters_stop=32

  while [ $(echo "$clusters < $clusters_stop" | bc) -eq 1 ]; do

    thld=36
    thld_step=2
    thld_stop=36

    tbhss load train-triplets \
      --cache tbhss.db \
      --name snli-$id-explore-train-$clusters \
      --file snli-small.train.txt \
      --clusters glove 0.125 1 $clusters 0 false \
      --segments 16 \
      --dimensions 32 \
      --buckets 40 \
      --saturation 1.2 \
      --length-normalization 0.75

    tbhss load test-triplets \
      --cache tbhss.db \
      --name snli-$id-explore-test-$clusters \
      --file snli-small.test.txt \
      --model snli-$id-explore-train-$clusters

    while [ $thld -le $thld_stop ]; do

      spec=8
      spec_range=4
      spec_step=1
      spec_stop=8

      while [ $spec -le $spec_stop ]; do

        specl=$(( spec - spec_range ))
        spech=$(( spec + spec_range ))

        [ $specl -lt 2 ] && specl=2

        echo Specificity $specl $spech
        echo Threshold $thld
        echo Clusters $clusters

        tbhss create encoder \
          --cache tbhss.db \
          --name snli-$id-explore-$clusters-$thld-$spec-$spec_range  \
          --triplets snli-$id-explore-train-$clusters snli-$id-explore-test-$clusters \
          --encoded-bits 256 \
          --clauses 8192 \
          --state-bits 8 \
          --threshold $thld \
          --specificity $specl $spech \
          --margin 0.1 \
          --loss-alpha 0.25 \
          --active-clause 0.85 \
          --boost-true-positive true \
          --evaluate-every 1 \
          --epochs 5

        spec=$(( spec + spec_step ))
      done
      thld=$(( thld + thld_step ))
    done
    clusters=$(echo "$clusters + $clusters_step" | bc)
  done

' 2>&1 >> explore.txt & tail -f explore.txt
