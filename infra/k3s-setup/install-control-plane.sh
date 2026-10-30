#!/bin/bash
# install-control-plane.sh — Cài k3s trên node control-plane
#
# Yêu cầu: setup-base-node.sh đã chạy xong
# Cách dùng: ./install-control-plane.sh   (KHÔNG dùng sudo: script tự gọi sudo khi cần,
#            chạy bằng sudo thì kubeconfig sẽ bị ghi vào /root thay vì user của bạn)
#
# Sau khi chạy xong:
#   - k3s server đang chạy (systemd service: k3s)
#   - kubectl có thể dùng không cần sudo (~/.kube/config)
#   - Script in ra NODE TOKEN để worker dùng join

set -e

# ── Cấu hình ────────────────────────────────────────────────────────────────
# Tên interface host-only (IP tĩnh kết nối nội bộ cluster)
# VMware Workstation: ens33  |  VirtualBox: enp0s8
INTERNAL_IF="${INTERNAL_IF:-ens33}"

MASTER_IP=$(ip a show "$INTERNAL_IF" 2>/dev/null \
  | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

if [ -z "$MASTER_IP" ]; then
  echo "❌ Không tìm thấy IP trên interface $INTERNAL_IF"
  echo "   Đặt biến INTERNAL_IF đúng trước khi chạy."
  echo "   VD: INTERNAL_IF=enp0s8 ./install-control-plane.sh"
  exit 1
fi

echo "======================================================"
echo " install-control-plane.sh"
echo " Master IP: $MASTER_IP (interface: $INTERNAL_IF)"
echo "======================================================"

# ── 1. Cài k3s server ───────────────────────────────────────────────────────
echo "[1/4] Cài k3s server..."
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --node-ip "$MASTER_IP" \
  --advertise-address "$MASTER_IP" \
  --flannel-iface "$INTERNAL_IF"
# --node-ip + --flannel-iface: bắt k3s dùng card host-only cho INTERNAL-IP và mạng pod.
# Thiếu --flannel-iface, VM có 2 card mạng dễ bị k3s chọn nhầm card NAT (lỗi nhóm đã gặp).

# Chờ k3s sẵn sàng
echo "      Chờ k3s khởi động..."
until sudo kubectl get nodes &>/dev/null; do
  sleep 3
done

# ── 2. Cấu hình kubeconfig cho user hiện tại ────────────────────────────────
echo "[2/4] Cấu hình kubeconfig..."
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Thêm vào .bashrc nếu chưa có
if ! grep -q 'KUBECONFIG' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export KUBECONFIG=$HOME/.kube/config' >> "$HOME/.bashrc"
fi
export KUBECONFIG="$HOME/.kube/config"

# ── 3. Verify cluster ───────────────────────────────────────────────────────
echo "[3/4] Kiểm tra node (cột INTERNAL-IP phải là $MASTER_IP)..."
kubectl get nodes -o wide

# ── 4. In TOKEN để worker join ──────────────────────────────────────────────
echo ""
echo "======================================================"
echo " [4/4] NODE TOKEN (copy để chạy join-worker.sh)"
echo "======================================================"
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
echo ""
echo "  TOKEN : $NODE_TOKEN"
echo "  MASTER: $MASTER_IP"
echo ""
echo "  Lệnh join trên mỗi worker:"
echo "  sudo ./join-worker.sh $MASTER_IP $NODE_TOKEN"
echo ""
echo "✅ Control-plane sẵn sàng. Chạy join-worker.sh trên 3 worker node."
