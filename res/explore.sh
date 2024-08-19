nohup stdbuf -oL sh -c '

  set -e

  id=45

  epochs=10

  wave=10000
  wave_step=*10
  wave_stop=10000

  while [ $(echo "$wave <= $wave_stop" | bc) -eq 1 ]; do

    buckets=10
    buckets_step=+4
    buckets_stop=10

    while [ $(echo "$buckets <= $buckets_stop" | bc) -eq 1 ]; do

      dimensions=32
      dimensions_step=+4
      dimensions_stop=32

      while [ $(echo "$dimensions <= $dimensions_stop" | bc) -eq 1 ]; do

        tbhss load train-triplets \
          --cache tbhss.db \
          --name snli-$id-explore-train-$dimensions-$buckets-$wave \
          --file snli-triplets.train.txt \
          --max-records 20000 \
          --clusters glove dbscan 2 0.645 3 \
          --dimensions $dimensions \
          --buckets $buckets \
          --wavelength $wave \
          --saturation 1.2 \
          --length-normalization 0.75

        tbhss load test-triplets \
          --cache tbhss.db \
          --name snli-$id-explore-test-$dimensions-$buckets-$wave \
          --file snli-triplets.test.txt \
          --max-records 2000 \
          --model snli-$id-explore-train-$dimensions-$buckets-$wave

        margin=0.1
        margin_step=+0.05
        margin_stop=0.1

        while [ $(echo "$margin <= $margin_stop" | bc) -eq 1 ]; do

          bits=512
          bits_step=*2
          bits_stop=2048

          while [ $(echo "$bits <= $bits_stop" | bc) -eq 1 ]; do

            spec=8
            spec_range=4
            spec_step=+1
            spec_stop=8

            while [ $(echo "$spec <= $spec_stop" | bc) -eq 1 ]; do

              specl=$(( spec - spec_range ))
              spech=$(( spec + spec_range ))

              [ $specl -lt 2 ] && specl=2

              echo Specificity $specl $spech
              echo Buckets $buckets
              echo Dimensions $dimensions
              echo Margin $margin
              echo Wave $wave
              echo Bits $bits

              tbhss create encoder \
                --cache tbhss.db \
                --name snli-$id-explore-$dimensions-$buckets-$margin-$wave-$bits-$spec-$spec_range \
                --triplets snli-$id-explore-train-$dimensions-$buckets-$wave snli-$id-explore-test-$dimensions-$buckets-$wave \
                --encoded-bits $bits \
                --clauses 8192 \
                --state-bits 8 \
                --threshold 36 \
                --specificity $specl $spech \
                --margin $margin \
                --loss-alpha 0.25 \
                --active-clause 0.85 \
                --boost-true-positive true \
                --evaluate-every 1 \
                --epochs $epochs

              spec=$(echo "$spec $spec_step" | bc)
            done
            bits=$(echo "$bits $bits_step" | bc)
          done
          margin=$(echo "$margin $margin_step" | bc)
        done
        dimensions=$(echo "$dimensions $dimensions_step" | bc)
      done
      buckets=$(echo "$buckets $buckets_step" | bc)
    done
    wave=$(echo "$wave $wave_step" | bc)
  done

' 2>&1 >> explore.txt & tail -f explore.txt
