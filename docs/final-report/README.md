# Bản thảo báo cáo NT533

[NT533-bao-cao-draft.docx](NT533-bao-cao-draft.docx) được ghép từ bản Word hiện có và dữ liệu trong repo tại `fc5bf03`, cập nhật ngày 21/11/2026.

## Nội dung đã ghép

- Giữ bố cục bốn chương, thông tin nhóm và định dạng bản gốc.
- Cập nhật định nghĩa TN1–TN3 thành scale-out tới pod Ready; cấu hình fibonacci, arrival-rate và min replica 1.
- Bổ sung phần dashboard OpenFaaS sáu panel, bằng chứng và giới hạn nghiệm thu.
- Bảng/hình TN1–TN4 theo hồ sơ nguồn; bảng summary sáu run spike TN5. Không tính scale latency khi chưa xác nhận mốc tải.
- Cập nhật mục lục và danh mục hình/bảng trong Word; kiểm tra dàn trang bằng bản PDF xuất từ Word. Bản thảo hiện có 22 trang, 8 bảng và 5 hình đánh số.

## Còn chờ chốt

- Mốc bắt đầu tải năm run TN5 và bộ HPA run1 khớp summary; commit/env thực tế và run cần loại.
- Quy ước thống kê trong báo cáo nguồn; số pod/restart TN4 theo hồ sơ người đo.
- CPU/RAM, p99 TN5 và nguồn metrics Kubernetes nếu có thu/bổ sung; không điền 0 cho dữ liệu thiếu.
- Nghiệm thu dashboard dưới tải và xác nhận nội dung chuyên môn của nhóm trước khi nộp.

Đây là bản thảo để nhóm rà soát, chưa phải báo cáo đã nghiệm thu. File Word gốc và dữ liệu thực nghiệm được giữ nguyên. Các file dựng/render dùng để kiểm tra được lưu ngoài repo.
