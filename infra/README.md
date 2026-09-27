# Infra — Hạ tầng & Cluster (Người 1)

## Mục tiêu

Dựng cụm Kubernetes multi-node (1 control-plane + 3 worker) bằng k3s,
chạy trên máy ảo VirtualBox/VMware qua Vagrant, sẵn sàng để Người 2
triển khai OpenFaaS lên đó.

## Cấu trúc

```
infra/
├── vagrant/          # Vagrantfile dựng 4 VM tự động
├── k3s-setup/         # Script cài k3s control-plane + join worker
└── networking/        # Cấu hình mạng nội bộ, Ingress controller
```

## Kế hoạch (theo timeline tuần 3-6)

- [ ] Tuần 3-4: Viết `Vagrantfile` dựng 4 VM (Ubuntu Server 22.04),
      cấu hình mạng nội bộ (host-only hoặc bridged) giữa các node
- [ ] Tuần 5-6: Script cài k3s trên control-plane, join 3 worker node,
      verify bằng `kubectl get nodes`, cài `metrics-server`

## Yêu cầu tài nguyên (tham khảo từ đề cương)

- Mỗi node: tối thiểu 2GB RAM
- Tổng cụm 4 node: khuyến nghị máy host có ít nhất 16GB RAM để chạy mượt

## Rủi ro cần lưu ý (từ đề cương)

| Rủi ro | Phương án |
|---|---|
| Laptop không đủ RAM chạy 4 VM cùng lúc | Giảm còn 3 node (1 control-plane + 2 worker), hoặc dùng `kind` thay VM thật |
| Node không join được cluster (lỗi network) | Dùng Vagrant script để tái tạo cluster tự động, tránh lỗi thao tác tay |

## Cách chạy (điền khi hoàn thành)

```bash
cd infra/vagrant
vagrant up          # dựng 4 VM
cd ../k3s-setup
./install-control-plane.sh
./join-worker.sh <token>   # chạy trên từng worker
```

## Kiểm tra cluster hoạt động

```bash
kubectl get nodes
# Kỳ vọng: 1 control-plane + 3 worker, tất cả STATUS = Ready
```
