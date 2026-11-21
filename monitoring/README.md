# Monitoring (Người 4)

## Phạm vi bàn giao ngày 21/11/2026

Đã hoàn thành cấu hình dashboard OpenFaaS cơ bản, export và kiểm tra import lại. Đây là phần bàn giao có minh chứng kiểm tra; **chưa phải nghiệm thu toàn bộ monitoring Kubernetes hoặc kiểm thử hiệu năng dưới tải**.

- [Dashboard JSON](grafana/dashboards/openfaas-overview.json): bản export từ dashboard chính UID `addhncs`, server version 4.
- [Minh chứng kiểm tra](verification/2026-11-21.json): kết quả triển khai, import, query và quan sát bộ lọc; giữ số lượng series thực tế, kể cả kết quả rỗng.
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
    └── 2026-11-21.json              # Minh chứng lịch sử; không phải kết quả đo hiệu năng
```

## Sáu panel đã bàn giao

| Panel | Nguồn/cách tính | Đơn vị và giới hạn |
|---|---|---|
| Request/s theo function | Rate `gateway_function_invocation_total`, gộp theo function | req/s, gồm tất cả mã HTTP; không phải target arrival-rate của k6 |
| Replica theo gateway | `max by (function_name)(gateway_service_count)` | Số nguyên; không thay thế desired/Ready replicas của Kubernetes |
| Latency phía gateway p50/p95/p99 | `histogram_quantile` trên rate `gateway_functions_seconds_bucket` | Giây, percentile ước lượng từ histogram; không phải TTFB client |
| Request thành công/s | Counter request lọc `code=~"2.."` | req/s |
| Tỷ lệ lỗi HTTP | Rate ngoài 2xx / rate tổng request | Ratio 0–1, dùng `percentunit`; không nhân thêm 100 trong query |
| Trạng thái scrape | `up{job=~"openfaas-pods|prometheus"}` | 1/0 theo target; không xác nhận cả bốn node Ready |

Các query rate dùng cửa sổ `[1m]`. Đây là cửa sổ quan sát dashboard, khác query điều khiển KEDA `[30s]` trong manifest hiện tại. Biến `function` lấy label từ `gateway_service_count`, hỗ trợ chọn một/nhiều/All; các panel function dùng `function_name=~"$function"`. Panel scrape độc lập với lựa chọn function.

## Import và kiểm tra

1. Truy cập Grafana đã có sẵn, vào **Dashboards → New → Import** và upload `openfaas-overview.json`.
2. Chọn datasource Prometheus đang thu metrics OpenFaaS. File dùng `${DS_PROMETHEUS}`, không khóa vào UID datasource của cluster gốc.
3. Để thử khôi phục, đổi **tên và UID** để tạo dashboard riêng. File giữ UID gốc `addhncs`; nếu muốn cập nhật dashboard gốc, export bản đang chạy và kiểm tra chỉnh sửa mới trước khi xác nhận ghi đè.
4. Chọn All, một function rồi nhiều function; kiểm tra replica legend tương ứng. Scrape panel phải tiếp tục hiển thị các target chung.
5. Khi có phiên tải đã thống nhất với người vận hành, chọn đúng khoảng thời gian tuyệt đối và đối chiếu request, mã HTTP, latency, replica với dữ liệu client/Kubernetes. Chưa có tải thì không coi bước này là đã nghiệm thu.

Dashboard gốc được kiểm tra với Grafana 12.3.1; export có `id: null`, `version: 1` để import, khác server version 4 tại thời điểm bàn giao. Không cần đổi datasource hay cài lại Prometheus/Grafana nếu hệ thống đã có nguồn phù hợp.

## Tiêu chí và bằng chứng

| Tiêu chí | Trạng thái thực tế |
|---|---|
| Đủ 6 panel, đơn vị, legend và biến function | Đã đối chiếu bản lưu server và export |
| Khôi phục bằng import, chọn đúng datasource | Đã import bản riêng UID `nt533-import-test`; 6 cấu hình panel và biến khớp bản chính |
| Query thực thi với All/fibonacci | 16 lượt kiểm tra trả `success`; một số query trả rỗng, không coi đó là đủ dữ liệu hiệu năng |
| UI All/một/hai function | Đã quan sát replica legend thay đổi đúng; scrape giữ target chung. Quan sát được ghi trong JSON, không có file ảnh xuất riêng |
| Success RPS và scrape có mẫu lịch sử | Có; cửa sổ kiểm tra 30 phút, lần lượt 10 và 158 mẫu hữu hạn |
| Tỷ lệ lỗi hữu hạn, request/latency đối chiếu dưới tải | Chưa hoàn tất; tỷ lệ lỗi có 0 mẫu hữu hạn trong lần kiểm tra range |
| CPU/RAM, Kubernetes desired/Ready replicas | Chưa hoàn tất; chưa có series tương ứng ở lần kiểm kê |
| Kiểm tra trạng thái metrics hiện tại | Lần thử lại cùng ngày bị timeout Grafana/gateway và không ping được master; chưa thể xác nhận đã bổ sung nguồn metrics |

Các kết quả live trong hồ sơ là **lịch sử kiểm tra**, không bảo đảm cluster đang truy cập được. Chi tiết thời điểm thử lại có trong `latest_connectivity_attempt` của minh chứng.

## Cách đọc khi dữ liệu trống

- `No data`: không có series phù hợp hoặc không đủ mẫu; không tự thay bằng 0.
- RPS bằng 0: có thể không có request mới nhưng counter vẫn được scrape.
- Error ratio hoặc percentile `NaN`: có thể không có request trong cửa sổ tính; không trình bày thành 0% lỗi hoặc 0 giây.
- `up=0`: scrape target thất bại; mất series là trường hợp khác. `up=1` không chứng minh workload hoặc toàn bộ node Ready.

Tỷ lệ lỗi có fallback 0 ở tử số khi counter tổng tồn tại và chưa có series lỗi; mẫu số 0 vẫn cho tỷ lệ không xác định. Không nối qua dữ liệu thiếu để tạo cảm giác có quan sát liên tục.

## Nền tảng và việc còn lại

Trung Đức đã cài Prometheus đi kèm OpenFaaS (namespace `openfaas`) và Grafana (namespace `monitoring`, NodePort `31782`). Datasource nội bộ: `http://prometheus.openfaas:9090`. Tại lần kiểm kê: global scrape 15s, gateway 5s, Prometheus self-scrape 10s. Thông tin đăng nhập không lưu trong thư mục này.

Huy tạo ba panel đầu và biến function theo hướng dẫn; phần hỗ trợ bổ sung ba panel, rà API, export/import và ghi minh chứng. Phần nền tảng đã có được tiếp nhận, không cài lại.

Còn cần khôi phục truy cập để kiểm tra metrics hiện tại, bổ sung nguồn CPU/RAM/node/pod và trạng thái Kubernetes nếu vẫn thiếu, rồi hoàn thành kiểm thử dưới tải trong khung giờ đã thống nhất. Kết quả HPA/KEDA từng run vẫn cần bàn giao cho phần tổng hợp.

**Không apply `prometheus/prometheus-config.yaml` trực tiếp**: đây là cấu hình tham khảo, có thể trùng ConfigMap OpenFaaS và ghi đè cấu hình đang phục vụ gateway/KEDA. Phải đối chiếu và sao lưu cấu hình đang chạy trước khi sửa. Chưa thay Prometheus, autoscaling hoặc sinh tải trong lần bàn giao này.
