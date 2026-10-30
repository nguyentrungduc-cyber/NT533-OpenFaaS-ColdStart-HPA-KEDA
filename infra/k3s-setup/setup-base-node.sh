#!/bin/bash
# setup-base-node.sh — Chuẩn bị node Ubuntu 22.04 trước khi cài k3s
# Chạy trên TẤT CẢ node (control-plane lẫn worker) trước các script khác.
#
# Việc làm:
#   1. Cài package cần thiết (curl, git, chrony)
#   2. Tắt swap (bắt buộc với Kubernetes)
#   3. Đồng bộ thời gian qua chrony (tránh timestamp lệch giữa các node)
#   4. Bật kernel modules cho containerd (overlay, br_netfilter)
#   5. Cấu hình sysctl forwarding

set -e

echo "======================================================"
echo " setup-base-node.sh — Chuẩn bị node $(hostname)"
echo "======================================================"

# ── 1. Cập nhật và cài package ──────────────────────────────────────────────
echo "[1/5] Cập nhật apt và cài package..."
sudo apt-get update -y -q
sudo apt-get install -y -q curl git chrony apt-transport-https ca-certificates

# ── 2. Tắt swap ─────────────────────────────────────────────────────────────
echo "[2/5] Tắt swap (yêu cầu bắt buộc của Kubernetes)..."
sudo swapoff -a
# Tắt vĩnh viễn qua /etc/fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "      swap hiện tại: $(swapon --show | wc -l) entry (phải = 0)"

# ── 3. Đồng bộ thời gian (chrony) ───────────────────────────────────────────
echo "[3/5] Bật chrony (NTP)..."
sudo systemctl enable --now chrony
sleep 2
chronyc tracking | grep -E "Reference|RMS offset|Stratum" || true

# ── 4. Kernel modules cho containerd ────────────────────────────────────────
echo "[4/5] Bật overlay và br_netfilter..."
cat <<MODULES | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
MODULES

sudo modprobe overlay
sudo modprobe br_netfilter

# ── 5. sysctl — IP forwarding và bridge netfilter ───────────────────────────
echo "[5/5] Cấu hình sysctl..."
cat <<SYSCTL | sudo tee /etc/sysctl.d/99-k3s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYSCTL
sudo sysctl --system > /dev/null

echo ""
echo "⚠️  Nhắc lại 2 việc script KHÔNG làm thay bạn:"
echo "   1. Netplan: ens33 IP tĩnh không gateway, ens37 dhcp4: yes"
echo "      (mẫu: infra/networking/netplan-example.yaml)"
echo "   2. Nếu VM này là bản clone: tạo lại machine-id rồi reboot"
echo "      sudo rm -f /etc/machine-id /var/lib/dbus/machine-id && sudo systemd-machine-id-setup"
echo ""
echo "✅ setup-base-node.sh hoàn tất trên $(hostname)"
echo "   → Tiếp theo: chạy install-control-plane.sh (master)"
echo "               hoặc join-worker.sh (worker)"
