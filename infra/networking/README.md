# Networking — Cấu hình mạng nội bộ & Ingress

## Sơ đồ mạng thực tế của cụm

```
Internet
    │
    │ NAT (VMware: ens37, VirtualBox: enp0s3)
    │
┌───┴──────────────────────────────────────────┐
│              192.168.16.0/24 (NAT)           │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│         192.168.243.0/24 (Host-only)         │
│                                               │
│  k3s-master   192.168.243.10  (ens33)        │
│  k3s-worker1  192.168.243.11  (ens33)        │
│  k3s-worker2  192.168.243.12  (ens33)        │
│  k3s-worker3  192.168.243.13  (ens33)        │
└──────────────────────────────────────────────┘
       ↑
       │ Tailscale overlay (100.88.160.0/24)
       │ Dùng để remote access từ các máy khác
```

## Ingress Controller

k3s tích hợp sẵn **Traefik** làm Ingress Controller (namespace: `kube-system`).
Không cần cài thêm — Traefik tự động được deploy khi k3s khởi động.

Kiểm tra:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl get svc -n kube-system traefik
```

## NodePort của OpenFaaS Gateway

OpenFaaS Gateway được expose qua NodePort:
- Port: **31112** (HTTP)
- Truy cập: `http://192.168.243.10:31112` hoặc bất kỳ worker IP + :31112

## Lưu ý: Internet trên các node

Mỗi node có 2 interface:
- `ens33` (host-only): IP tĩnh, kết nối nội bộ cluster — **luôn hoạt động**
- `ens37` (NAT): cấp DHCP, cần chạy `dhclient ens37` sau reboot để có internet

Xem thêm: `../k3s-setup/join-worker.sh` phần xử lý internet khi cài agent.
