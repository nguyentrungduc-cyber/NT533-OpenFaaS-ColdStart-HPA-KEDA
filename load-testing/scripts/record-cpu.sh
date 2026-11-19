#!/bin/bash
# record-cpu.sh <file.csv>   (Ctrl+C de dung)
# Ghi CPU trung binh (%) cua cac node moi 5 giay, lay tu `kubectl top nodes` (metrics-server).
# Node chua co so (<unknown>) bi bo qua. Luu y: metrics-server cap nhat theo cua so ~15 giay,
# nen so cho moi mau co the lap lai; k6 chay tren master nen co tinh vao CPU cua master.
OUT=${1:?cach dung: record-cpu.sh <file.csv>}
echo "ts_ms,cpu_pct_avg" > "$OUT"
while true; do
  P=$(kubectl top nodes --no-headers | awk '$3 ~ /^[0-9]+%$/ {gsub("%","",$3); s+=$3; n++} END{if(n) printf "%.1f", s/n}')
  echo "$(date +%s%3N),$P" >> "$OUT"
  sleep 5
done
