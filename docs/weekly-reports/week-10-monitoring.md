# Tuần 10 — Bàn giao dashboard OpenFaaS cơ bản

**Người phụ trách:** Huỳnh Hoàng Huy — Người 4, Monitoring & Báo cáo.

**Ngày:** 21/11/2026.

**Phạm vi:** Mốc hoàn thành cấu hình, export và kiểm tra khôi phục; chưa kết luận hoàn tất toàn bộ monitoring Kubernetes.

## Đã làm

- Tiếp nhận Prometheus/Grafana do Trung Đức cài sẵn; kiểm tra datasource và các metrics gateway.
- Hoàn thiện [dashboard 6 panel](../../monitoring/grafana/dashboards/openfaas-overview.json): tổng RPS, replica gateway, latency p50/p95/p99, success RPS, tỷ lệ lỗi ngoài 2xx và scrape health.
- Giữ đơn vị/legend rõ ràng, bộ lọc function hỗ trợ All/một/nhiều lựa chọn; scrape health không phụ thuộc function.
- Export từ server version 4, hỗ trợ chọn datasource khi import; đã import thành bản riêng và đối chiếu 6 panel, biến cùng 16 lượt query All/fibonacci trả success.
- Quan sát UI: replica legend theo lựa chọn, scrape target giữ nguyên. Request/latency chưa có tải để nghiệm thu; không coi query success là dữ liệu đầy đủ.
- Bàn giao [hướng dẫn và tiêu chí](../../monitoring/README.md), [minh chứng kiểm tra](../../monitoring/verification/2026-11-21.json). Hồ sơ được tổng hợp từ các lần kiểm tra đã lưu; không chạy lại live trong lần đóng gói này.

Chưa tạo commit/PR cho gói bàn giao này. Không ghi mã commit chưa tồn tại. Việc phân tích TN1–TN4 được thực hiện ngoài repo như bản đối chiếu nội bộ; các báo cáo thực nghiệm trong `load-testing/results/` tiếp tục là nguồn của nhóm, chưa thay bằng bộ thống kê khác.

## Vấn đề gặp phải

- Dữ liệu rỗng/NaN khi không có tải: giữ nguyên trạng thái, không ép thành 0. Lần kiểm tra tỷ lệ lỗi chưa có mẫu hữu hạn.
- Chưa có nguồn CPU/RAM node/pod và Kubernetes desired/Ready/node status trong datasource ở lần kiểm kê. Replica gateway không thay thế các chỉ tiêu này.
- JSON cấu hình Prometheus trong repo chỉ là mẫu; không apply để tránh ghi đè nguồn đang dùng cho gateway/KEDA.

## Việc còn lại

- Huy kiểm tra lại scrape target và metrics sau khi truy cập được; nhờ Trung Đức xử lý nguồn/RBAC/exporter nếu vẫn thiếu.
- Bổ sung panel CPU/RAM, desired/Ready replicas khi nguồn đã được xác minh; xác nhận bốn node Ready bằng dữ liệu Kubernetes phù hợp.
- Hẹn lịch kiểm thử dashboard dưới tải, đối chiếu request/mã HTTP/latency và thay đổi replica; lưu khoảng thời gian và số liệu để nghiệm thu.
- Đã tiếp nhận summary và replica của 3 run HPA + 3 run KEDA spike sau pull fc5bf03; Trung Đức phụ trách bổ sung thông tin còn thiếu; còn cần mốc tải, ghép đúng HPA run1 và cấu hình lúc đo, CPU nếu đã thu.
- Sau khi dữ liệu và phương pháp được nhóm xác nhận, Huy chốt bảng/hình, báo cáo và slide trong `docs/final-report/`. Đã ghép [bản Word 22 trang](../final-report/NT533-bao-cao-draft.docx) từ bản gốc, bổ sung TN1–TN5 và monitoring; có 8 bảng, 5 hình, đã cập nhật mục lục/kiểm tra bố cục. Đây là bản thảo, chưa phải báo cáo nghiệm thu; chưa có slide cuối.
