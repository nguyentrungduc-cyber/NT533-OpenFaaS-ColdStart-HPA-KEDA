#!/bin/bash
# record-replicas.sh <function> <file.csv>   (Ctrl+C de dung)
# Ghi so pod Ready va so pod mong muon (desired) cua Deployment moi giay.
# ready de trong khi chua co pod nao Ready (kubectl khong in readyReplicas luc do).
FN=${1:?cach dung: record-replicas.sh <function> <file.csv>}
OUT=${2:?thieu ten file csv}
echo "ts_ms,ready,desired" > "$OUT"
while true; do
  R=$(kubectl -n openfaas-fn get deploy "$FN" -o jsonpath='{.status.readyReplicas},{.spec.replicas}')
  echo "$(date +%s%3N),$R" >> "$OUT"
  sleep 1
done
