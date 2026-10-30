# Infra — Hạ tầng & Cluster (Người 1)

## Mục tiêu

Dựng cụm Kubernetes multi-node (1 control-plane + 3 worker) bằng k3s,
chạy trên 4 máy ảo VMware Workstation trên laptop Người 1.

**Trạng thái: đã xong.** Cụm thực tế được dựng bằng cách tạo 1 VM rồi clone ra 3 VM
(không dùng Vagrant). `vagrant/Vagrantfile` là phương án tự động hoá, **chưa được chạy thử**.

## Cấu trúc

```
infra/
├── vagrant/          # Vagrantfile dựng 4 VM tự động
├── k3s-setup/         # Script cài k3s control-plane + join worker
└── networking/        # Cấu hình mạng nội bộ, Ingress controller
```

## Kế hoạch (theo timeline tuần 3-6)

- [x] Tuần 3-4: 4 VM Ubuntu Server 22.04, host-only 192.168.243.0/24 + NAT
- [x] Tuần 5-6: k3s control-plane + 3 worker, metrics-server (có sẵn trong k3s)
- [x] Cài nền tảng: Helm, OpenFaaS, KEDA, Grafana, k6, Tailscale

## Yêu cầu tài nguyên (tham khảo từ đề cương)

- Mỗi node: tối thiểu 2GB RAM
- Tổng cụm 4 node: khuyến nghị máy host có ít nhất 16GB RAM để chạy mượt

## Rủi ro cần lưu ý (từ đề cương)

| Rủi ro | Phương án |
|---|---|
| Laptop không đủ RAM chạy 4 VM cùng lúc | Giảm còn 3 node (1 control-plane + 2 worker), hoặc dùng `kind` thay VM thật |
| Node không join được cluster (lỗi network) | Dùng Vagrant script để tái tạo cluster tự động, tránh lỗi thao tác tay |

## Cách dựng lại cụm (quy trình đã kiểm chứng)

1. Tạo 1 VM Ubuntu Server 22.04 trên VMware: card 1 Host-only (ens33), card 2 NAT (ens37).
2. Cấu hình mạng theo [`networking/netplan-example.yaml`](./networking/netplan-example.yaml).
3. Chạy `k3s-setup/setup-base-node.sh`, tắt VM, clone ra 3 worker.
4. Trên mỗi bản clone: đổi hostname, đổi IP ens33, **tạo lại machine-id**, reboot
   (xem [`networking/README.md`](./networking/README.md)).
5. Master (không dùng sudo): `./k3s-setup/install-control-plane.sh`
6. Mỗi worker: `sudo ./k3s-setup/join-worker.sh 192.168.243.10 <TOKEN>`

## Kiểm tra cluster hoạt động

```bash
kubectl get nodes -o wide
# Kỳ vọng: 1 control-plane + 3 worker, STATUS = Ready,
# INTERNAL-IP = 192.168.243.10 / .11 / .12 / .13
```
