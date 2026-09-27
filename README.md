# NT533 — Nghiên cứu Cold-Start & So sánh HPA vs KEDA trên OpenFaaS

**Hệ tính toán phân bố (NT533) — UIT**

Nền tảng Function-as-a-Service (FaaS) tự triển khai trên cụm Kubernetes
multi-node (k3s), tập trung nghiên cứu 2 bài toán:

1. **Tối ưu độ trễ cold-start** — đặc trưng cốt lõi phân biệt serverless
   thật với microservices thông thường
2. **So sánh định lượng HPA vs KEDA** — 2 chiến lược autoscaling phổ biến,
   dựa trên CPU/RAM (HPA) so với sự kiện/RPS (KEDA)

## Kiến trúc tổng quan

```
Client → OpenFaaS Gateway → Function Pod (trên Worker Node)
                ↓                    ↑
         Autoscaler (HPA/KEDA) ──────┘
                ↓
      Prometheus (scrape metrics) → Grafana (dashboard)
```

Cụm gồm **1 control-plane + 3 worker node**, triển khai trên máy ảo
VirtualBox/VMware bằng Vagrant, dùng **k3s** (Kubernetes nhẹ) thay vì
kubeadm để giảm tải RAM.

## Cấu trúc thư mục

```
├── infra/                      # Người 1 — Hạ tầng & Cluster
│   ├── vagrant/                 # Vagrantfile dựng 4 VM tự động
│   ├── k3s-setup/                # Script cài k3s control-plane + worker
│   └── networking/               # Cấu hình mạng nội bộ, Ingress
│
├── functions/                   # Người 2 — Serverless Platform & Cold-start
│   ├── hello-world/               # Function demo tối thiểu để test nhanh
│   ├── image-processing/          # Xử lý ảnh
│   ├── email-sender/              # Gửi email
│   ├── data-processor/            # Xử lý dữ liệu
│   └── pdf-generator/             # Tạo PDF (function thứ 5)
│
├── coldstart-optimization/       # Người 2 — Trọng tâm nghiên cứu #1
│   ├── warm-pool/                  # Chiến lược giữ pod ấm sẵn
│   ├── image-optimization/         # Distroless image, giảm kích thước
│   └── probe-tuning/               # Điều chỉnh readiness/liveness probe
│
├── autoscaling/                  # Người 3 — Trọng tâm nghiên cứu #2
│   ├── hpa/                        # Cấu hình HPA (CPU/RAM-based)
│   └── keda/                       # Cấu hình KEDA (event/RPS-based)
│
├── load-testing/                 # Người 3 — Đo lường & thu thập số liệu
│   ├── k6-scripts/                  # Kịch bản tạo tải bằng k6/hey
│   └── results/
│       ├── coldstart/                # Kết quả đo cold-start latency
│       └── hpa-vs-keda/              # Kết quả so sánh 2 chiến lược scale
│
├── monitoring/                   # Người 4 — Giám sát thời gian thực
│   ├── prometheus/                  # Cấu hình scrape targets
│   └── grafana/dashboards/          # Dashboard JSON export
│
└── docs/                          # Người 4 — Tổng hợp & Báo cáo
    ├── weekly-reports/               # Báo cáo tiến độ theo tuần (15 tuần)
    ├── architecture/                 # Sơ đồ kiến trúc, diagram
    └── final-report/                 # Báo cáo cuối kỳ + slide bảo vệ
```

## Thành viên & phân công

| Thành viên | Vai trò | Nhiệm vụ chính | Thư mục phụ trách |
|---|---|---|---|
| Người 1 | Hạ tầng & Cluster | Dựng 4 VM, cài k3s multi-node, networking, Ingress | `infra/` |
| Người 2 | Serverless Platform & Cold-start | Cài OpenFaaS, viết 5+ functions, cold-start optimization | `functions/`, `coldstart-optimization/` |
| Người 3 | Autoscaling & Testing | So sánh HPA vs KEDA, kịch bản load test, thu thập số liệu | `autoscaling/`, `load-testing/` |
| Người 4 | Monitoring & Báo cáo | Prometheus/Grafana, tổng hợp số liệu, viết báo cáo | `monitoring/`, `docs/` |

*Lưu ý: Người 3 cần cluster từ Người 1 và function từ Người 2 để test —
xem timeline chi tiết ở `docs/weekly-reports/`.*

## Công nghệ sử dụng

| Lớp | Công cụ |
|---|---|
| Ảo hóa | VirtualBox/VMware + Vagrant |
| Hệ điều hành | Ubuntu Server 22.04 LTS |
| Container runtime | containerd (đi kèm k3s) |
| Orchestration | k3s |
| Serverless | OpenFaaS |
| Autoscaling | Kubernetes HPA + metrics-server, KEDA |
| Load testing | k6 hoặc hey |
| Monitoring | Prometheus + Grafana |

## Kế hoạch 15 tuần

Xem chi tiết timeline từng tuần tại [`docs/weekly-reports/README.md`](./docs/weekly-reports/README.md).

## Kết quả mong đợi

- Cụm Kubernetes multi-node hoạt động ổn định, demo trực tiếp được
- OpenFaaS với tối thiểu 5 function thực tế, hỗ trợ scale-to-zero
- Biểu đồ so sánh cold-start latency giữa các chiến lược tối ưu
- Biểu đồ so sánh hiệu năng HPA vs KEDA
- Dashboard Grafana trực quan thời gian thực
- Báo cáo phân tích + khuyến nghị chiến lược phù hợp theo workload
