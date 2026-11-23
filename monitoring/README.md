# Monitoring (Người 4)

## Phạm vi bàn giao (cập nhật 23/11/2026)

Dashboard OpenFaaS đã đối chiếu dưới tải bằng 6 run TN5 (21/11) còn trong Prometheus: request, mã lỗi và replica khớp k6/recorder. **Chưa có** CPU/RAM và desired/Ready của Kubernetes vì Prometheus chưa scrape node-exporter, cAdvisor, kube-state-metrics; các panel này đã dựng sẵn và đang báo chờ nguồn.

- [Dashboard JSON](grafana/dashboards/openfaas-overview.json): bản export từ dashboard chính UID `addhncs`, server version 6.
- [Minh chứng 23/11](verification/2026-11-23.json): thay đổi v5/v6, import lại, đối chiếu TN5, tách lỗi trước/sau khi đủ pod. [Minh chứng 21/11](verification/2026-11-21.json): triển khai v4, import, query và bộ lọc.
- [Báo cáo mốc công việc](../docs/weekly-reports/week-10-monitoring.md): phần đã làm, vấn đề và phần còn lại.

## Cấu trúc

```text
monitoring/
├── README.md
├── prometheus/
│   └── prometheus-config.yaml       # Tham khảo; chưa phải cấu hình đã apply
├── grafana/dashboards/
│   └── openfaas-overview.json       # Dashboard import được, chọn datasource khi import
└── verification/
    ├── 2026-11-21.json              # Minh chứng v4; không phải kết quả đo hiệu năng
    └── 2026-11-23.json              # Minh chứng v5 và đối chiếu TN5
```

## Panel đã bàn giao

Bốn panel bắt buộc theo kế hoạch Người 4: Request/s, **Request lỗi/s** (v6), Latency p95 (hiển thị kèm p50/p99) và số pod (Replica theo gateway). Các panel còn lại là bổ sung. Dashboard làm mới 5 giây, mặc định 15 phút.

| Panel | Nguồn/cách tính | Đơn vị và giới hạn |
|---|---|---|
| Request/s theo function | Rate `gateway_function_invocation_total`, gộp theo function | req/s, gồm tất cả mã HTTP; không phải target arrival-rate của k6 |
| Replica theo gateway | `max by (function_name)(gateway_service_count)` | Số nguyên; không thay thế desired/Ready replicas của Kubernetes |
| Latency phía gateway p50/p95/p99 | `histogram_quantile` trên rate `gateway_functions_seconds_bucket` | Giây, percentile ước lượng từ histogram; không phải TTFB client |
| Request thành công/s | Counter request lọc `code=~"2.."` | req/s |
| Tỷ lệ lỗi HTTP | Rate ngoài 2xx / rate tổng request | Ratio 0–1, dùng `percentunit`; không nhân thêm 100 trong query |
| Request lỗi/s (v6) | `sum by (function_name, code)(rate(...{code!~"2.."}[1m]))` | req/s theo mã HTTP; TN5 chỉ có 502 |
| Trạng thái scrape | `up{job=~"openfaas-pods|prometheus"}` | 1/0 theo target; không xác nhận cả bốn node Ready |
| Metric điều khiển KEDA (v5) | Query trigger của `keda-scaledobject.yaml`: `sum(rate(...[30s]))` và chia `gateway_service_count`; vạch ngưỡng 24 | req/s; chỉ fibonacci; chỉ là tín hiệu điều khiển khi ScaledObject đang áp dụng |
| Replica hiện tại (v5) | Stat, giá trị cuối `gateway_service_count` | `0 pod` tô đỏ; không có series hiện "Không có dữ liệu (≠ 0 pod)" |
| Row "Tài nguyên & Kubernetes" (v5, thu gọn) | CPU/RAM node (node-exporter), CPU/RAM pod `openfaas-fn` (cAdvisor), desired/Ready/HPA desired và Node Ready (kube-state-metrics) | Hiện "Chưa có nguồn: …" cho tới khi bổ sung exporter tương ứng |

Annotation **Mốc thí nghiệm NT533** đọc annotation có tag `nt533`. Đã thêm 6 annotation TN5 (tag `tn5`, `hpa`/`keda`, `runN`) theo cửa sổ thời gian của `*.replicas.csv`; đây không phải mốc bắt đầu tải đã xác nhận. Lần chạy sau nên thêm annotation đúng lúc bắt đầu/kết thúc k6 với tag chế độ.

Các query rate dùng cửa sổ `[1m]`. Đây là cửa sổ quan sát dashboard, khác query điều khiển KEDA `[30s]` trong manifest hiện tại. Biến `function` lấy label từ `gateway_service_count`, hỗ trợ chọn một/nhiều/All; các panel function dùng `function_name=~"$function"`. Panel scrape độc lập với lựa chọn function.

## Import và kiểm tra

1. Truy cập Grafana đã có sẵn, vào **Dashboards → New → Import** và upload `openfaas-overview.json`.
2. Chọn datasource Prometheus đang thu metrics OpenFaaS. File dùng `${DS_PROMETHEUS}`, không khóa vào UID datasource của cluster gốc.
3. Để thử khôi phục, đổi **tên và UID** để tạo dashboard riêng. File giữ UID gốc `addhncs`; nếu muốn cập nhật dashboard gốc, export bản đang chạy và kiểm tra chỉnh sửa mới trước khi xác nhận ghi đè.
4. Chọn All, một function rồi nhiều function; kiểm tra replica legend tương ứng. Scrape panel phải tiếp tục hiển thị các target chung.
5. Khi có phiên tải đã thống nhất với người vận hành, chọn đúng khoảng thời gian tuyệt đối và đối chiếu request, mã HTTP, latency, replica với dữ liệu client/Kubernetes. Chưa có tải thì không coi bước này là đã nghiệm thu.

Dashboard gốc được kiểm tra với Grafana 12.3.1; export có `id: null`, `version: 1` để import, khác server version 6 tại thời điểm bàn giao. Annotation lưu trong database Grafana, không nằm trong file export. Không cần đổi datasource hay cài lại Prometheus/Grafana nếu hệ thống đã có nguồn phù hợp.

## Tiêu chí và bằng chứng

| Tiêu chí | Trạng thái thực tế |
|---|---|
| Đủ panel, đơn vị, legend và biến function | Đã đối chiếu bản lưu server v6 và export |
| Khôi phục bằng import, chọn đúng datasource | Import lại v6 vào UID `nt533-import-test` (23/11): panel, query, fieldConfig, row và annotation query khớp bản chính |
| Query thực thi với All/fibonacci | 16 lượt kiểm tra trả `success`; một số query trả rỗng, không coi đó là đủ dữ liệu hiệu năng |
| UI All/một/hai function | Đã quan sát replica legend thay đổi đúng; scrape giữ target chung. Quan sát được ghi trong JSON, không có file ảnh xuất riêng |
| Success RPS và scrape có mẫu lịch sử | Có; cửa sổ kiểm tra 30 phút, lần lượt 10 và 158 mẫu hữu hạn |
| Request và mã lỗi dưới tải | Đạt trên 6 run TN5: tổng request gateway bằng 1,000–1,011 lần `http_reqs` k6; số 502 ở gateway lệch số request lỗi của k6 dưới 1,1%. Lệch nhỏ do `increase()` ngoại suy |
| Replica dưới tải | Đạt: replica tối đa theo gateway trùng ready/desired tối đa của recorder ở cả 6 run (4 hoặc 5) |
| Latency dưới tải | Có dữ liệu histogram; chưa so trực tiếp với k6 vì k6 đo cả timeout 10s phía client |
| CPU/RAM, Kubernetes desired/Ready replicas | Chưa hoàn tất: 23/11 vẫn 0 series `node_*`, `container_*`, `kube_*`; panel đã dựng sẵn |
| Metrics KEDA sau thay đổi | Dashboard không đổi Prometheus; query trigger KEDA vẫn trả dữ liệu |

Các kết quả live trong hồ sơ là **lịch sử kiểm tra**, không bảo đảm cluster đang truy cập được. Chi tiết thời điểm thử lại có trong `latest_connectivity_attempt` của minh chứng.

## Cách đọc khi dữ liệu trống

- `No data`: không có series phù hợp hoặc không đủ mẫu; không tự thay bằng 0.
- RPS bằng 0: có thể không có request mới nhưng counter vẫn được scrape.
- Error ratio hoặc percentile `NaN`: có thể không có request trong cửa sổ tính; không trình bày thành 0% lỗi hoặc 0 giây.
- `up=0`: scrape target thất bại; mất series là trường hợp khác. `up=1` không chứng minh workload hoặc toàn bộ node Ready.

Tỷ lệ lỗi có fallback 0 ở tử số khi counter tổng tồn tại và chưa có series lỗi; mẫu số 0 vẫn cho tỷ lệ không xác định. Không nối qua dữ liệu thiếu để tạo cảm giác có quan sát liên tục.

## Nền tảng và việc còn lại

Trung Đức đã cài Prometheus đi kèm OpenFaaS (namespace `openfaas`) và Grafana bằng Helm chart `grafana/grafana` (namespace `monitoring`, NodePort `31782`). Datasource nội bộ: `http://prometheus.openfaas:9090`. Tại lần kiểm kê: global scrape 15s, gateway 5s, Prometheus self-scrape 10s. Thông tin đăng nhập không lưu trong thư mục này.

Huy tạo ba panel đầu và biến function theo hướng dẫn; phần hỗ trợ bổ sung ba panel, rà API, export/import và ghi minh chứng. Phần nền tảng đã có được tiếp nhận, không cài lại.

Còn cần người vận hành cluster bổ sung node-exporter, scrape kubelet/cAdvisor (kèm RBAC) và kube-state-metrics vào Prometheus đang chạy, sau đó kiểm tra row "Tài nguyên & Kubernetes" có dữ liệu và query trigger KEDA vẫn chạy. Mốc bắt đầu tải từng run TN5 vẫn cần xác nhận.

**Không apply `prometheus/prometheus-config.yaml` trực tiếp**: đây là cấu hình tham khảo, có thể trùng ConfigMap OpenFaaS và ghi đè cấu hình đang phục vụ gateway/KEDA. Phải đối chiếu và sao lưu cấu hình đang chạy trước khi sửa. Chưa thay Prometheus, autoscaling hoặc sinh tải trong lần bàn giao này.
