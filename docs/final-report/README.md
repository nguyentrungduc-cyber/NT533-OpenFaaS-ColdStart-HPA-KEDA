# Bản thảo báo cáo NT533

[NT533-bao-cao-draft.docx](NT533-bao-cao-draft.docx) được ghép từ bản Word hiện có và dữ liệu trong repo tại `890058e`, cập nhật ngày 23/11/2026. Slide: [NT533 – Cold-start & HPA vs KEDA trên OpenFaaS1.pptx](NT533%20–%20Cold-start%20&%20HPA%20vs%20KEDA%20trên%20OpenFaaS1.pptx), 20 slide.

## Nội dung đã ghép

- Giữ bố cục bốn chương, thông tin nhóm và định dạng bản gốc.
- Cập nhật định nghĩa TN1–TN3 thành scale-out tới pod Ready; cấu hình fibonacci, arrival-rate và min replica 1.
- Phần dashboard Grafana version 6: 4 panel bắt buộc theo kế hoạch Người 4 (request/s, request lỗi/s, latency p95, số pod) cùng các panel bổ sung; bằng chứng đối chiếu dưới tải với 6 run TN5 và giới hạn nghiệm thu.
- Bảng/hình TN1–TN4 theo hồ sơ nguồn; bảng TN5 có request, failed, p50, p95 và dropped của sáu run, đối chiếu trực tiếp summary k6. Cập nhật mô tả cấu hình và nhận xét theo TN5 mới; không dùng các kết luận nguyên nhân chưa được xác minh. Không tính scale latency khi thiếu mốc tải.
- Bản cuối kì (22/11/2026): bổ sung Bảng 9 và Hình 6 về diễn biến replica TN5 từ các file `.replicas.csv` (replica tối đa, thời gian từ lần tăng đầu tới desired tối đa, trễ Ready); mục 9.3 tổng hợp kết quả; hạn chế về scale-to-zero và mốc tải; mục 4 Chương IV phân công công việc (Bảng 10). Thống nhất đánh số đề mục và chú thích, đổi dòng ngày cập nhật ở bìa thành thời gian thực hiện.
- Bản 23/11/2026: Hình 1 kiến trúc hệ thống; mục 3.1 Phát hiện về OpenFaaS CE; cài đặt bằng Helm thay arkade; Hình 8–9 chụp Grafana run1 HPA/KEDA; mục 2 Chương IV Khó khăn và cách khắc phục. Sửa nhận định về lỗi TN5: theo counter gateway, 64–91% response 502 xuất hiện sau khi replica đạt tối đa (minh chứng `monitoring/verification/2026-11-23.json`), nguyên nhân chưa kiểm chứng.
- Bản 24/11/2026: bỏ hình kiến trúc Kubernetes tổng quát (không phải thiết kế của nhóm); thêm Hình 2 sơ đồ mạng cụm k3s (mục 2.2 Chương II); các hình sau giữ số 3–9 (Grafana là Hình 8–9). TN4 bỏ lượt 1 pod run1 do lỗi khi đo; Bảng 7 thêm cột Restart (1 pod run2 restart 2 lần, 2 và 3 pod không restart); vẽ lại Hình 5 với 3 lượt.
- Mục lục và danh mục hình/bảng cập nhật bằng Word; bản PDF xuất từ Word có 28 trang, 10 bảng và 9 hình đánh số.

## Còn chờ chốt

- Bộ HPA run1 khớp summary; commit/env thực tế và run cần loại. Các chỉ tiêu cần mốc tải được bỏ khỏi phân tích nếu không có dữ liệu, không yêu cầu tạo lại file `.start`.
- Quy ước thống kê trong báo cáo nguồn; số pod/restart TN4 theo hồ sơ người đo.
- CPU/RAM, p99 TN5 và nguồn metrics Kubernetes nếu có thu/bổ sung; không điền 0 cho dữ liệu thiếu.
- Nhóm xác nhận nhận định mới về lỗi 502 TN5 và nội dung chuyên môn trước khi nộp; video demo dự phòng.

Đây là bản thảo để nhóm rà soát, chưa phải báo cáo đã nghiệm thu. File Word gốc và dữ liệu thực nghiệm được giữ nguyên. Các file dựng/render dùng để kiểm tra được lưu ngoài repo.
