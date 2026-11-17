#!/usr/bin/env bash
#
# coldstart.sh — đo cold-start theo định nghĩa scale-out.
#
# ĐỊNH NGHĨA ĐANG DÙNG
#
# Cold-start = thời gian từ lúc ra lệnh tăng thêm một pod cho tới khi pod mới
# chuyển sang trạng thái Ready.
#
# Định nghĩa kinh điển (độ trễ của request đầu tiên sau khi function về 0 pod)
# KHÔNG đo được trên OpenFaaS CE, vì faas-netes luôn kéo function về lại 1 pod
# trong vài giây mà không cần request nào. Bằng chứng:
#   load-testing/results/scale-to-zero-test.md
#
# Định nghĩa scale-out giữ nguyên mọi bước tốn thời gian của một lần khởi động
# lạnh (xếp lịch pod, pull image nếu node chưa có, khởi tạo container, khởi động
# runtime, chờ readiness probe) và chỉ bỏ phần request xếp hàng ở gateway.
#
# CÁCH ĐO MỖI LẦN
#
#   1. Đưa function về 1 pod, chờ ổn định
#   2. Ghi mốc t0
#   3. kubectl scale --replicas=2
#   4. Chờ tới khi readyReplicas = 2
#   5. Ghi mốc t1; cold-start = t1 - t0
#   6. Ghi lại node mà pod mới được xếp vào
#   7. Hạ về 1 pod, chờ ổn định rồi lặp
#
# SAI SỐ
#
# Vòng lặp kiểm tra chờ 0,2 giây mỗi vòng, cộng thời gian thực thi của lệnh
# kubectl, nên mỗi số đo có sai số cỡ vài trăm mili-giây. Sai số này như nhau
# giữa các kịch bản nên không ảnh hưởng việc so sánh tương đối.
#
# TRƯỚC KHI CHẠY
#
#   - Bật đủ 4 máy ảo, kiểm tra: kubectl get nodes
#   - Chạy ./infra/scripts/fix-pullpolicy.sh (deploy sẽ đặt lại về Always)
#   - Function không được gắn HPA hay ScaledObject:
#       kubectl -n openfaas-fn get hpa,scaledobject
#   - Không ai deploy hay tạo tải lên cụm trong lúc đo
#
# CÁCH DÙNG
#
#   ./load-testing/coldstart.sh fibonacci 31
#   ./load-testing/coldstart.sh image-resize 6 results/coldstart/tn3-co-image.csv
#
# Lần đo đầu luôn cao hơn hẳn nên quy ước của nhóm là bỏ nó. Vì vậy chạy 31 lần
# để lấy 30 số liệu. Phần tổng kết ở cuối tự bỏ lần đầu.
#
set -euo pipefail

FN="${1:-}"
RUNS="${2:-31}"
OUT="${3:-}"
NS="${NS:-openfaas-fn}"
POLL="${POLL:-0.2}"
TIMEOUT="${TIMEOUT:-120}"

if [ -z "$FN" ]; then
  echo "Dùng: $0 <tên-function> [số-lần] [file-csv]" >&2
  echo "Ví dụ: $0 fibonacci 31" >&2
  exit 1
fi

if ! kubectl -n "$NS" get deploy "$FN" >/dev/null 2>&1; then
  echo "Không tìm thấy Deployment '$FN' trong namespace $NS." >&2
  exit 1
fi

# Cảnh báo nếu còn cơ chế autoscaling gắn vào function
if kubectl -n "$NS" get hpa,scaledobject 2>/dev/null | grep -q "$FN"; then
  echo "CẢNH BÁO: '$FN' đang có HPA hoặc ScaledObject. Số pod sẽ bị cơ chế khác" >&2
  echo "điều khiển và số đo không dùng được. Gỡ chúng trước khi đo." >&2
  exit 1
fi

IMAGE=$(kubectl -n "$NS" get deploy "$FN" \
          -o jsonpath='{.spec.template.spec.containers[0].image}')
POLICY=$(kubectl -n "$NS" get deploy "$FN" \
          -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')
COMMIT=$(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo "unknown")

if [ -z "$OUT" ]; then
  OUT="$(dirname "$0")/results/coldstart/${FN}-$(date +%Y%m%d-%H%M%S).csv"
fi
mkdir -p "$(dirname "$OUT")"

if [ "$POLICY" != "IfNotPresent" ]; then
  echo "CẢNH BÁO: imagePullPolicy = $POLICY (nên là IfNotPresent)." >&2
  echo "Số đo sẽ lẫn thời gian gọi registry. Chạy ./infra/scripts/fix-pullpolicy.sh trước." >&2
  echo "Nhấn Ctrl-C để dừng, hoặc Enter để chạy tiếp." >&2
  read -r _
fi

echo "# function=$FN image=$IMAGE policy=$POLICY commit=$COMMIT runs=$RUNS" | tee "$OUT.meta"
echo "lan,elapsed_ms,node,bat_dau" > "$OUT"

ready_count() {
  kubectl -n "$NS" get deploy "$FN" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0
}

wait_ready() {           # wait_ready <số pod mong muốn> ; trả về 0 nếu đạt
  local want="$1" deadline
  deadline=$(( $(date +%s) + TIMEOUT ))
  while :; do
    local n
    n=$(ready_count); n=${n:-0}
    [ "$n" = "$want" ] && return 0
    [ "$(date +%s)" -ge "$deadline" ] && return 1
    sleep "$POLL"
  done
}

cleanup() {
  echo >&2
  echo "Đang đưa $FN về 1 pod..." >&2
  kubectl -n "$NS" scale deploy "$FN" --replicas=1 >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

echo "Chuẩn bị: đưa $FN về 1 pod..."
kubectl -n "$NS" scale deploy "$FN" --replicas=1 >/dev/null
wait_ready 1 || { echo "Không ổn định được ở 1 pod sau ${TIMEOUT}s." >&2; exit 1; }
sleep 3

for i in $(seq 1 "$RUNS"); do
  before=$(kubectl -n "$NS" get pods -l "faas_function=$FN" \
             -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}')

  t0=$(date +%s%3N)
  started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  kubectl -n "$NS" scale deploy "$FN" --replicas=2 >/dev/null

  if wait_ready 2; then
    t1=$(date +%s%3N)
    elapsed=$(( t1 - t0 ))
  else
    echo "  lần $i: QUÁ HẠN sau ${TIMEOUT}s, bỏ qua" >&2
    kubectl -n "$NS" scale deploy "$FN" --replicas=1 >/dev/null
    wait_ready 1 || true
    sleep 3
    continue
  fi

  # Node của pod mới: pod nào có mặt bây giờ mà trước đó chưa có
  node="?"
  for p in $(kubectl -n "$NS" get pods -l "faas_function=$FN" \
               -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}'); do
    case " $before " in
      *" $p "*) ;;
      *) node=$(kubectl -n "$NS" get pod "$p" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "?") ;;
    esac
  done

  printf '%d,%d,%s,%s\n' "$i" "$elapsed" "$node" "$started_at" >> "$OUT"
  if [ "$i" = "1" ]; then
    printf '  lần %-3s %6s ms  %-12s (bỏ, lần đầu)\n' "$i" "$elapsed" "$node"
  else
    printf '  lần %-3s %6s ms  %-12s\n' "$i" "$elapsed" "$node"
  fi

  kubectl -n "$NS" scale deploy "$FN" --replicas=1 >/dev/null
  wait_ready 1 || true
  sleep 3
done

echo
echo "Kết quả thô: $OUT"
echo

# Bỏ dòng tiêu đề và lần đo đầu, sắp xếp sẵn bằng sort để awk nào cũng chạy
# (Ubuntu mặc định dùng mawk, không có hàm asort của gawk).
tail -n +3 "$OUT" | cut -d, -f2 | sort -n | awk '
{ v[++n] = $1; s += $1 }
END {
  if (n < 2) { print "Chưa đủ số liệu để tổng kết."; exit }
  mean = s / n
  for (i = 1; i <= n; i++) d += (v[i] - mean) ^ 2
  sd = sqrt(d / n)

  # percentile theo nearest-rank: hạng = ceil(p * n)
  p95 = int(0.95 * n); if (p95 < 0.95 * n) p95++; if (p95 < 1) p95 = 1
  p99 = int(0.99 * n); if (p99 < 0.99 * n) p99++; if (p99 < 1) p99 = 1

  printf "Đã bỏ lần đo đầu. Dùng %d số liệu.\n\n", n
  printf "  mean      %8.1f ms\n", mean
  printf "  min       %8d ms\n", v[1]
  printf "  median    %8d ms\n", v[int((n + 1) / 2)]
  printf "  p95       %8d ms\n", v[p95]
  printf "  p99       %8d ms\n", v[p99]
  printf "  max       %8d ms\n", v[n]
  printf "  std dev   %8.1f ms\n", sd
}'
