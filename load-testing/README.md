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

## Đo HPA vs KEDA trên fibonacci (quy trình một lần đo)

Script: `k6-scripts/hpa-vs-keda.js` (chọn kịch bản bằng `PROFILE`: steady, ramp, spike, step, burst; mức tải tính theo
`C` = 40 req/s), `scripts/record-replicas.sh` (ghi số pod mỗi giây), `analysis/analyze.py` (phân tích và vẽ hình).
Điều kiện: `requests` của fibonacci đã là 350m (xem `functions/stack.yml`), bộ co giãn của CE đã tắt, không ai khác
tạo tải lên cụm trong lúc đo. Chạy trên master, từ thư mục `load-testing/`. Đặt `TOOL` là `hpa` hoặc `keda`.

1. Gỡ cơ chế kia, áp cơ chế cần đo, và kiểm tra chỉ có một bộ co giãn:
   ```bash
   kubectl delete -f ../autoscaling/keda/keda-scaledobject.yaml --ignore-not-found   # khi đo HPA
   kubectl apply  -f ../autoscaling/hpa/hpa-config.yaml
   kubectl -n openfaas-fn get hpa,scaledobject
   ```
   (Khi đo KEDA thì làm ngược lại: xóa `hpa-config.yaml`, áp `keda-scaledobject.yaml`.)
2. Đưa fibonacci về 1 pod và chờ 2 phút cho ổn định (`kubectl -n openfaas-fn get deploy fibonacci`).
3. Cửa sổ SSH thứ hai: `bash scripts/record-replicas.sh fibonacci results/hpa-vs-keda/${TOOL}_spike_run1.csv`
4. Cửa sổ thứ nhất, ghi mốc bắt đầu tải rồi chạy k6:
   ```bash
   date +%s%3N > results/hpa-vs-keda/${TOOL}_spike_run1.start
   k6 run -e PROFILE=spike -e C=40 --summary-trend-stats="avg,min,med,max,p(90),p(95),p(99)"      --summary-export=results/hpa-vs-keda/${TOOL}_spike_run1.summary.json k6-scripts/hpa-vs-keda.js
   ```
5. Dừng `record-replicas.sh` (Ctrl+C) khi pod đã về 1 (để đo được thời gian giảm pod; `analyze.py` tự cắt mọi lần đo của cùng kịch bản về cùng một cửa sổ thời gian = lần ghi ngắn nhất, nên pod-giây so sánh được), chờ 6 phút cho pod giảm về 1 trước lần đo sau (HPA chờ 5 phút mới giảm pod).
6. Tên file dạng `<hpa|keda>_<kịch bản>_run<N>` với đủ 3 đuôi `.csv`, `.start`, `.summary.json`.
   Mỗi cặp (bộ co giãn x kịch bản) chạy 5 lần. `.csv` và `.start` được giữ trong git; `.summary.json` cũng được giữ.
7. Phân tích: `python analysis/analyze.py hpa-vs-keda` (cần pandas, matplotlib); kết quả ở `analysis/out/`.
   Boxplot cold-start: `python analysis/analyze.py coldstart results/coldstart/<file>.csv ...`.

## Timeline (theo đề cương)

- Tuần 11: Đo cold-start latency cho 3 chiến lược tối ưu
- Tuần 12: Chạy song song trên HPA và KEDA, thu thập số liệu so sánh
- Tuần 13: Tổng hợp số liệu, vẽ biểu đồ (chuyển sang `docs/final-report/`)
