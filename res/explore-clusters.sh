nohup stdbuf -oL sh -c '

  set -e

  id=104

  pts=2
  pts_step=1
  pts_stop=2

  while [ $pts -le $pts_stop ]; do

    eps=0.64
    eps_step=0.001
    eps_stop=0.65

    while [ $(echo "$eps < $eps_stop" | bc) -eq 1 ]; do

      echo "eps: $eps  min_pts: $pts"

      tbhss create clusters \
        --cache tbhss.db \
        --name clusters-$id-explore-train-$pts-$eps \
        --words glove \
        --algorithm dbscan $pts $eps true \
        --filter-words snli60-train

      eps=$(echo "$eps + $eps_step" | bc)
    done
    pts=$(( pts + pts_step ))
  done

' 2>&1 >> explore.txt & tail -f explore.txt

