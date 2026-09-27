# Autoscaling — HPA vs KEDA (Người 3) — Trọng tâm nghiên cứu #2

## Mục tiêu

Triển khai và so sánh định lượng 2 chiến lược autoscaling trên **cùng
một kịch bản tải** (theo đề cương mục 1.2).

| Thư mục | Chiến lược | Cơ chế scale |
|---|---|---|
| `hpa/` | Kubernetes HPA | Dựa trên CPU/RAM usage |
| `keda/` | KEDA | Dựa trên sự kiện/RPS/queue-length |

## Timeline (theo đề cương)

- Tuần 9: Cấu hình HPA + KEDA, kiểm thử scale thủ công cho cả 2
- Tuần 12: Chạy load test song song, thu thập số liệu so sánh

## Rủi ro cần lưu ý

> KEDA cấu hình phức tạp hơn dự kiến, không kịp so sánh với HPA
> → **Phương án:** Ưu tiên hoàn thiện HPA + cold-start trước; KEDA làm
> sau, nếu thiếu thời gian thì báo cáo dựa trên cấu hình mặc định.

## Kết quả mong đợi

So sánh: thời gian phản hồi, tốc độ scale (từ lúc tải tăng đến lúc pod
mới sẵn sàng), mức sử dụng tài nguyên — xem chi tiết cách đo tại
[`../load-testing/`](../load-testing/).
