# Load Testing (Người 3)

## Mục tiêu

Xây dựng bộ công cụ load-testing để tạo tải và đo: thời gian phản hồi,
tốc độ scale, độ trễ cold-start.

## Công cụ: k6 (khuyến nghị) hoặc hey

## Cấu trúc

```
load-testing/
├── k6-scripts/
│   ├── coldstart-test.js       # Đo latency lần gọi đầu tiên sau scale-to-zero
│   └── autoscaling-test.js     # Tạo tải tăng dần, đo tốc độ scale HPA/KEDA
└── results/
    ├── coldstart/               # Kết quả JSON/CSV từng lần chạy cold-start test
    └── hpa-vs-keda/             # Kết quả so sánh 2 chiến lược scale
```

## Cách chạy

Chạy từ thư mục `load-testing/`. Mặc định script gọi gateway `http://192.168.243.10:31112`;
từ máy khác qua Tailscale thì thêm `-e GATEWAY=http://100.88.160.40:31112`.

```bash
k6 run k6-scripts/coldstart-test.js --out json=results/coldstart/run-01.json
k6 run k6-scripts/autoscaling-test.js --out json=results/hpa-vs-keda/hpa-run-01.json
```

Hai script hiện gọi function `hello-world`; quy trình bật/tắt HPA và KEDA giữa các lần chạy
ghi ở đầu `k6-scripts/autoscaling-test.js`.

`.gitignore` bỏ qua mọi file `*.json` trong `results/` (file thô rất lớn), chỉ giữ file
`*.summary.json`. Muốn đưa kết quả lên repo thì lưu bản tóm tắt với đuôi `.summary.json`.

## Timeline (theo đề cương)

- Tuần 11: Đo cold-start latency cho 3 chiến lược tối ưu
- Tuần 12: Chạy song song trên HPA và KEDA, thu thập số liệu so sánh
- Tuần 13: Tổng hợp số liệu, vẽ biểu đồ (chuyển sang `docs/final-report/`)
