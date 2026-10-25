#!/bin/bash
# join-worker.sh — Join worker node vào k3s cluster
#
# Yêu cầu: setup-base-node.sh đã chạy xong
# Cách dùng: sudo ./join-worker.sh <control-plane-ip> <node-token>
#
# Lấy token trên control-plane:
#   sudo cat /var/lib/rancher/k3s/server/node-token
#
# Ví dụ:
#   sudo ./join-worker.sh 192.168.243.10 K107535...::server:b4a94b...

set -e

CONTROL_PLANE_IP="${1}"
TOKEN="${2}"
# Interface NAT (để tạm thời lấy internet kéo k3s installer)
# VMware Workstation: ens37  |  VirtualBox: enp0s3
NAT_IF="${NAT_IF:-ens37}"
# Interface host-only (kết nối nội bộ cluster)
INTERNAL_IF="${INTERNAL_IF:-ens33}"

# ── Kiểm tra tham số ────────────────────────────────────────────────────────
if [ -z "$CONTROL_PLANE_IP" ] || [ -z "$TOKEN" ]; then
  echo "Cách dùng: sudo ./join-worker.sh <control-plane-ip> <node-token>"
  echo ""
  echo "Lấy token trên control-plane:"
  echo "  sudo cat /var/lib/rancher/k3s/server/node-token"
  exit 1
fi

echo "======================================================"
echo " join-worker.sh — $(hostname)"
echo " Control-plane: $CONTROL_PLANE_IP"
echo "======================================================"

# ── 1. Bật kết nối internet tạm thời qua NAT interface ──────────────────────
# (cần để tải k3s installer từ get.k3s.io)
echo "[1/3] Bật internet qua NAT interface ($NAT_IF)..."
sudo dhclient "$NAT_IF" 2>/dev/null || true
# Xóa default route cũ (nếu có), thêm route qua NAT
GATEWAY=$(ip route show dev "$NAT_IF" | grep 'default via' | awk '{print $3}' | head -1)
if [ -n "$GATEWAY" ]; then
  sudo ip route del default 2>/dev/null || true
  sudo ip route add default via "$GATEWAY" dev "$NAT_IF"
  echo "      Default route → $GATEWAY via $NAT_IF"
fi

# ── 2. Cài k3s agent và join cluster ────────────────────────────────────────
echo "[2/3] Cài k3s agent và join cluster..."
WORKER_IP=$(ip a show "$INTERNAL_IF" 2>/dev/null \
  | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${CONTROL_PLANE_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  sh -s - agent \
  --node-ip "${WORKER_IP:-}"

# ── 3. Verify ───────────────────────────────────────────────────────────────
echo "[3/3] k3s agent started. Kiểm tra trên control-plane:"
echo "      kubectl get nodes"
echo ""
echo "  Nếu muốn xóa default route NAT sau khi join:"
echo "  sudo ip route del default dev $NAT_IF"
echo ""
echo "✅ $(hostname) đã join cluster tại $CONTROL_PLANE_IP"
