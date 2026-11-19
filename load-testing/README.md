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
`C` = 40 req/s; nền của spike và step là 0,5C = 20 req/s, xem `../autoscaling/README.md`), `scripts/record-replicas.sh`
(ghi số pod mỗi giây), `scripts/record-cpu.sh` (ghi CPU trung bình của các node mỗi 5 giây), `analysis/analyze.py`
(phân tích và vẽ hình). Chạy trên master, từ thư mục `load-testing/`. Đặt `TOOL` là `hpa` hoặc `keda`.

**Chuẩn bị (mỗi buổi đo, trước lần đầu):**
- `requests` của fibonacci là 350m: `kubectl -n openfaas-fn get deploy fibonacci -o jsonpath='{.spec.template.spec.containers[0].resources}'`
- Image fibonacci có sẵn trên cả 4 node (ghcr.io từ VM không ổn định, từng làm pod thứ 5 trễ ~104 giây). Kéo trước bằng
  `kubectl -n openfaas-fn scale deploy fibonacci --replicas=5`, chờ 5 pod Ready, rồi `--replicas=1`.
- Bộ co giãn của CE đã tắt (không còn Alertmanager); báo nhóm không tạo tải lên cụm trong lúc đo.
- Sau khi gateway khởi động lại, gọi fibonacci vài lần (`curl -X POST -d 20000 $GATEWAY/function/fibonacci`) để series Prometheus
  đã tồn tại; nếu không, `rate()` bỏ qua phần tăng của lần xuất hiện đầu tiên và KEDA có thể thấy 0 req/s lúc đầu.
- Chạy recorder và k6 trong `tmux` trên master (`tmux new -s do`; thoát bằng Ctrl+B rồi D; vào lại `tmux attach -t do`),
  vì tắt SSH sẽ dừng đo.

1. Gỡ cơ chế kia, áp cơ chế cần đo, và kiểm tra chỉ có một bộ co giãn:
   ```bash
   kubectl delete -f ../autoscaling/keda/keda-scaledobject.yaml --ignore-not-found   # khi đo HPA
   kubectl apply  -f ../autoscaling/hpa/hpa-config.yaml
   kubectl -n openfaas-fn get hpa,scaledobject
   ```
   (Khi đo KEDA thì làm ngược lại: xóa `hpa-config.yaml`, áp `keda-scaledobject.yaml`.)
2. Đưa fibonacci về 1 pod và chờ 2 phút cho ổn định (`kubectl -n openfaas-fn get deploy fibonacci`).
3. Hai cửa sổ (hoặc hai pane tmux) ghi song song:
   `bash scripts/record-replicas.sh fibonacci results/hpa-vs-keda/${TOOL}_spike_run1.csv`
   và `bash scripts/record-cpu.sh results/hpa-vs-keda/${TOOL}_spike_run1.cpu.csv`
4. Cửa sổ thứ ba, ghi mốc bắt đầu tải rồi chạy k6:
   ```bash
   date +%s%3N > results/hpa-vs-keda/${TOOL}_spike_run1.start
   k6 run -e PROFILE=spike -e C=40 --summary-trend-stats="avg,min,med,max,p(90),p(95),p(99)"      --summary-export=results/hpa-vs-keda/${TOOL}_spike_run1.summary.json k6-scripts/hpa-vs-keda.js
   ```
   Xem `dropped_iterations` trong kết quả k6: lớn hơn 0 nghĩa là k6 không kịp gửi đủ request, tải thật thấp hơn kế hoạch.
5. Dừng hai recorder (Ctrl+C) khi pod đã về 1 (để đo được thời gian giảm pod; `analyze.py` tự cắt mọi lần đo của cùng
   kịch bản về cùng một cửa sổ thời gian = lần ghi ngắn nhất, nên pod-giây so sánh được), chờ 6 phút cho pod giảm về 1
   trước lần đo sau (stabilization window của HPA là 300 giây).
6. Tên file dạng `<hpa|keda>_<kịch bản>_run<N>` với đủ 3 đuôi `.csv`, `.start`, `.summary.json` (và `.cpu.csv` nếu có,
   không bắt buộc). Cả bốn loại file đều được giữ trong git.
7. Ma trận đo: đợt 1 là 5 kịch bản x 2 bộ co giãn x 3 lần, chạy xen kẽ HPA và KEDA để nhiễu của cụm chia đều cho cả hai.
   Đợt 2 nâng spike và step lên 5 lần nếu còn thời gian.
8. Phân tích: `python analysis/analyze.py hpa-vs-keda` (cần pandas, matplotlib); kết quả ở `analysis/out/`.
   Mốc "tải bắt đầu tăng" và "hết tải" của từng kịch bản nằm trong bảng `MARKS` đầu `analyze.py` (phải sửa cùng lúc với
   `stages` trong `hpa-vs-keda.js`): thời gian phản ứng tính từ lúc tải tăng, thời gian giảm pod tính từ lúc hết tải.
   Boxplot cold-start: `python analysis/analyze.py coldstart results/coldstart/<file>.csv ...`.

## Timeline (theo đề cương)

- Tuần 11: Đo cold-start latency cho 3 chiến lược tối ưu
- Tuần 12: Chạy song song trên HPA và KEDA, thu thập số liệu so sánh
- Tuần 13: Tổng hợp số liệu, vẽ biểu đồ (chuyển sang `docs/final-report/`)
