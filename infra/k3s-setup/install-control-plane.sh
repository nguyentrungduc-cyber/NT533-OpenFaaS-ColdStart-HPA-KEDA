#!/bin/bash
# install-control-plane.sh — Cài k3s trên node control-plane
# TODO (Người 1): hoàn thiện script, test trên VM thật

set -e

echo "=== Cài đặt k3s server (control-plane) ==="

# TODO: curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644

echo "=== Lấy token để worker join ==="
# TODO: cat /var/lib/rancher/k3s/server/node-token

echo "=== Kiểm tra node ==="
# TODO: kubectl get nodes

echo "Hoàn tất. Ghi lại token ở trên để dùng cho join-worker.sh"
