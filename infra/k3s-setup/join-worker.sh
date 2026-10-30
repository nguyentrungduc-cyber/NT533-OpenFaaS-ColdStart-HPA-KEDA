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

# ── 1. Kiểm tra internet (cần để tải k3s installer) ─────────────────────────
# Nếu netplan đã cấu hình đúng (ens33 không gateway, ens37 dhcp4: yes — xem
# infra/networking/netplan-example.yaml) thì đã có internet sẵn, bước này bỏ qua.
echo "[1/3] Kiểm tra internet..."
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
  echo "      Đã có internet."
else
  echo "      Chưa có internet, thử bật qua $NAT_IF..."
  sudo dhclient "$NAT_IF" 2>/dev/null || true
  GATEWAY=$(ip route show dev "$NAT_IF" | grep 'default via' | awk '{print $3}' | head -1)
  if [ -n "$GATEWAY" ]; then
    sudo ip route replace default via "$GATEWAY" dev "$NAT_IF"
    echo "      Default route → $GATEWAY via $NAT_IF"
  fi
fi

# Máy clone từ cùng một VM phải có machine-id khác nhau, nếu không DHCP có thể
# cấp trùng IP và mạng giữa các node hỏng (lỗi nhóm đã gặp).
echo "      machine-id của node này: $(cat /etc/machine-id)"
echo "      → So với các node khác; nếu trùng, chạy: sudo rm -f /etc/machine-id /var/lib/dbus/machine-id && sudo systemd-machine-id-setup && sudo reboot"

# ── 2. Cài k3s agent và join cluster ────────────────────────────────────────
echo "[2/3] Cài k3s agent và join cluster..."
WORKER_IP=$(ip a show "$INTERNAL_IF" 2>/dev/null \
  | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
if [ -z "$WORKER_IP" ]; then
  echo "❌ Không tìm thấy IP trên interface $INTERNAL_IF (đặt biến INTERNAL_IF đúng)."
  exit 1
fi

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${CONTROL_PLANE_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  sh -s - agent \
  --node-ip "$WORKER_IP" \
  --flannel-iface "$INTERNAL_IF"

# ── 3. Verify ───────────────────────────────────────────────────────────────
echo "[3/3] k3s agent started. Kiểm tra trên control-plane:"
echo "      kubectl get nodes -o wide   (INTERNAL-IP của node này phải là $WORKER_IP)"
echo ""
echo "✅ $(hostname) đã join cluster tại $CONTROL_PLANE_IP"
