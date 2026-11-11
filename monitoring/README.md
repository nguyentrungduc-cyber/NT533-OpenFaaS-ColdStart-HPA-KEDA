# Monitoring (Người 4)

## Mục tiêu

Triển khai hệ thống giám sát thời gian thực (Prometheus + Grafana),
tích hợp metrics từ OpenFaaS & Kubernetes.

## Cấu trúc

```
monitoring/
├── prometheus/
│   └── prometheus-config.yaml   # Chỉ để tham khảo, KHÔNG apply (xem bên dưới)
└── grafana/
    └── dashboards/              # Dashboard export (JSON), hiện chưa có file nào
```

## Hiện trạng (Người 1 đã cài sẵn)

- Prometheus: đi kèm OpenFaaS, namespace `openfaas`, địa chỉ trong cluster
  `http://prometheus.openfaas:9090` (dùng làm datasource cho Grafana). Đã có sẵn cấu hình
  scrape gateway, đủ cho Grafana và KEDA.
- Grafana: Helm chart `grafana/grafana`, namespace `monitoring`, NodePort `31782`
  (`http://192.168.243.10:31782`, qua Tailscale: `http://100.88.160.40:31782`).

**Không apply `prometheus/prometheus-config.yaml` lên cluster khi chưa kiểm tra:** lệnh
trong file tạo ConfigMap có thể trùng tên ConfigMap của OpenFaaS và ghi đè cấu hình gốc
(xem cảnh báo đầu file).

## Timeline (theo đề cương)

- Tuần 10: Triển khai Prometheus + Grafana, tích hợp metrics từ OpenFaaS & K8s

## Dashboard cần có (theo đề cương)

- CPU, RAM usage theo node/pod
- Số pod đang chạy theo function (để quan sát HPA/KEDA scale trực quan)
- Request/s
- Latency (P50/P95/P99)

## Rủi ro cần lưu ý

> Thiếu thời gian làm phần monitoring
> → **Phương án:** Ưu tiên Prometheus + Grafana cơ bản trước, bỏ qua
> alerting nếu thiếu thời gian.
