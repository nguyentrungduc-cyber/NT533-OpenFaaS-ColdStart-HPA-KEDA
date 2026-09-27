#!/bin/bash
# join-worker.sh — Join worker node vào cluster k3s
# Cách dùng: ./join-worker.sh <control-plane-ip> <token>
# TODO (Người 1): hoàn thiện script, test trên VM thật

set -e

CONTROL_PLANE_IP=$1
TOKEN=$2

if [ -z "$CONTROL_PLANE_IP" ] || [ -z "$TOKEN" ]; then
    echo "Cach dung: ./join-worker.sh <control-plane-ip> <token>"
    exit 1
fi

echo "=== Join worker vao cluster tai $CONTROL_PLANE_IP ==="

# TODO: curl -sfL https://get.k3s.io | K3S_URL="https://${CONTROL_PLANE_IP}:6443" K3S_TOKEN="${TOKEN}" sh -

echo "Hoan tat. Kiem tra tren control-plane bang: kubectl get nodes"
