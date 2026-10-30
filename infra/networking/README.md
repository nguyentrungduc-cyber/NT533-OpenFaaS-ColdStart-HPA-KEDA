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
       │ Tailscale (chỉ cài trên master, IP 100.88.160.40)
       │ Dùng để các thành viên truy cập từ xa
```

## Ingress Controller

k3s tích hợp sẵn **Traefik** làm Ingress Controller (namespace: `kube-system`).
Không cần cài thêm — Traefik tự động được deploy khi k3s khởi động.

Kiểm tra:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl get svc -n kube-system traefik
```

## Các cổng dịch vụ (NodePort)

| Dịch vụ | Trên laptop Người 1 | Thành viên khác (qua Tailscale) |
|---|---|---|
| OpenFaaS Gateway | `http://192.168.243.10:31112` | `http://100.88.160.40:31112` |
| Grafana | `http://192.168.243.10:31782` | `http://100.88.160.40:31782` |
| SSH master | `ssh ubuntu@192.168.243.10` | `ssh <user>@100.88.160.40` |

NodePort mở trên mọi node, nên gọi vào IP của worker cũng được.

## Internet trên các node

Mỗi node có 2 interface:
- `ens33` (host-only): IP tĩnh, mạng nội bộ cluster, **không đặt gateway**
- `ens37` (NAT): `dhcp4: yes`, tự làm đường ra internet

Cấu hình mẫu: [`netplan-example.yaml`](./netplan-example.yaml). Với cấu hình này
internet có sẵn sau mỗi lần khởi động, không cần chạy `dhclient` hay sửa route bằng tay.

## Cài k3s trên máy 2 card mạng

Bắt buộc dùng `--node-ip <IP ens33>` và `--flannel-iface ens33` (đã có trong
`../k3s-setup/`). Thiếu 2 tham số này k3s có thể chọn nhầm card NAT làm INTERNAL-IP,
làm hỏng mạng giữa các pod. Kiểm tra sau khi join:

```bash
kubectl get nodes -o wide   # INTERNAL-IP phải là 192.168.243.10–13
```

## Lưu ý khi clone VM

Các VM clone từ cùng một máy phải có `/etc/machine-id` khác nhau, nếu không DHCP có thể
cấp trùng IP. Tạo lại trên mỗi bản clone:

```bash
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo reboot
```
