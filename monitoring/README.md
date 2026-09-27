# Monitoring (Người 4)

## Mục tiêu

Triển khai hệ thống giám sát thời gian thực (Prometheus + Grafana),
tích hợp metrics từ OpenFaaS & Kubernetes.

## Cấu trúc

```
monitoring/
├── prometheus/
│   └── prometheus-config.yaml   # Cấu hình scrape targets
└── grafana/
    └── dashboards/
        └── openfaas-overview.json   # Dashboard export (JSON)
```

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
