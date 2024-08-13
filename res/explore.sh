nohup stdbuf -oL sh -c '

  set -e

  thld=32
  thld_step=2
  thld_stop=40

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

      tbhss create encoder \
        --cache tbhss.db \
        --name snli20-explore-$spec-$thld  \
        --triplets snli13-train snli13-test \
        --encoded-bits 128 \
        --clauses 1024 \
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

' 2>&1 >> explore.txt & tail -f explore.txt
