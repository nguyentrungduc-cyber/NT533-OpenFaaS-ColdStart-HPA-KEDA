#!/usr/bin/env bash
#
# fix-pullpolicy.sh — đặt imagePullPolicy cho mọi function về IfNotPresent.
#
# VÌ SAO CẦN SCRIPT NÀY
#
# Chart OpenFaaS có tham số functions.imagePullPolicy, và nhóm đã đặt nó:
#
#   helm upgrade openfaas openfaas/openfaas -n openfaas --reuse-values \
#     --set functions.imagePullPolicy=IfNotPresent
#
# Biến môi trường xuống tới container faas-netes đúng như mong đợi
# (image_pull_policy=IfNotPresent, kiểm bằng kubectl get pod -l app=gateway).
# Nhưng faas-netes 0.18.17 (Community Edition) vẫn tạo Deployment với
# imagePullPolicy: Always. Đã thử cả hai đường và đều không ăn:
#   - faas-cli deploy đè lên function đang có
#   - faas-cli remove rồi faas-cli deploy lại (tạo Deployment hoàn toàn mới)
# Kiểm chứng ngày 17/11/2026.
#
# Nên cách duy nhất chạy được là vá thẳng Deployment, và đó là việc script này làm.
#
# VÌ SAO QUAN TRỌNG VỚI ĐỒ ÁN
#
# Với Always, mỗi lần tạo pod kubelet đều gọi lên GHCR đối chiếu digest, kể cả khi
# image đã nằm sẵn trên node. Hệ quả:
#   - Mọi số đo cold-start cộng thêm một khoảng thời gian phụ thuộc mạng.
#   - TN3 (pre-pull) mất ý nghĩa, vì vế "image đã có sẵn" vẫn phải hỏi registry.
#
# KHI NÀO PHẢI CHẠY
#
# Sau MỌI lần faas-cli deploy, vì deploy sẽ ghi đè lại thành Always.
# Chạy script này rồi mới đo. Script an toàn khi chạy nhiều lần: function nào đã
# đúng thì bỏ qua, không tạo pod mới.
#
# CÁCH DÙNG
#
#   ./infra/scripts/fix-pullpolicy.sh              # mặc định: openfaas-fn, IfNotPresent
#   NS=openfaas-fn POLICY=Always ./infra/scripts/fix-pullpolicy.sh   # đổi ngược lại
#
set -euo pipefail

NS="${NS:-openfaas-fn}"
POLICY="${POLICY:-IfNotPresent}"

case "$POLICY" in
  Always|IfNotPresent|Never) ;;
  *) echo "POLICY không hợp lệ: $POLICY (chỉ nhận Always, IfNotPresent, Never)" >&2; exit 1 ;;
esac

deploys=$(kubectl -n "$NS" get deploy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if [ -z "$deploys" ]; then
  echo "Không có Deployment nào trong namespace $NS." >&2
  exit 1
fi

changed=0
while IFS= read -r d; do
  [ -n "$d" ] || continue
  cur=$(kubectl -n "$NS" get deploy "$d" \
          -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')
  if [ "$cur" = "$POLICY" ]; then
    printf '  bỏ qua  %-18s đã là %s\n' "$d" "$POLICY"
  else
    kubectl -n "$NS" patch deploy "$d" --type=json \
      -p="[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/imagePullPolicy\",\"value\":\"$POLICY\"}]" \
      >/dev/null
    printf '  đã vá   %-18s %s -> %s\n' "$d" "$cur" "$POLICY"
    changed=$((changed + 1))
  fi
done <<< "$deploys"

if [ "$changed" -eq 0 ]; then
  echo
  echo "Không có gì phải đổi."
  exit 0
fi

echo
echo "Chờ $changed Deployment tạo lại pod..."
while IFS= read -r d; do
  [ -n "$d" ] || continue
  kubectl -n "$NS" rollout status deploy/"$d" --timeout=120s >/dev/null || {
    echo "CẢNH BÁO: $d chưa sẵn sàng sau 120 giây, kiểm tra bằng kubectl -n $NS get pods" >&2
  }
done <<< "$deploys"

echo
kubectl -n "$NS" get deploy -o custom-columns=\
NAME:.metadata.name,POLICY:.spec.template.spec.containers[0].imagePullPolicy,IMAGE:.spec.template.spec.containers[0].image

echo
echo "Xong. Kiểm pod: kubectl -n $NS get pods"
