while true
do
    echo "[$(date)] $(curl -s localhost:9876/api/workspace)"
    sleep 1
done