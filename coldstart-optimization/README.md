# Cold-Start Optimization (Người 2) — Trọng tâm nghiên cứu #1

## Mục tiêu

Thử nghiệm và so sánh các chiến lược giảm độ trễ cold-start — đây là
**trọng tâm thực nghiệm chính** của đồ án (theo đề cương mục 3).

## 3 chiến lược cần thử nghiệm

| Thư mục | Chiến lược | Ý tưởng |
|---|---|---|
| `warm-pool/` | Warm-pool | Giữ sẵn 1 số pod "ấm" (không scale về 0), tránh phải khởi động lạnh hoàn toàn |
| `image-optimization/` | Tối ưu container image | Dùng distroless/alpine base image, giảm kích thước → pull + start nhanh hơn |
| `probe-tuning/` | Điều chỉnh probe | Tinh chỉnh `readiness`/`liveness probe` timing để pod được đánh dấu "sẵn sàng" sớm hơn |

## Cách đo (liên kết với Load Testing)

Mỗi chiến lược cần đo **cold-start latency** bằng cùng 1 kịch bản tải
(xem [`../load-testing/`](../load-testing/)), rồi so sánh với baseline
(function `hello-world` mặc định, không tối ưu gì).

## Timeline (theo đề cương)

- Tuần 11: Thử nghiệm cả 3 chiến lược, đo latency

## Kết quả mong đợi

- Biểu đồ so sánh cold-start latency: Baseline vs Warm-pool vs Image tối ưu vs Probe tuning
- Khuyến nghị: chiến lược nào phù hợp cho loại workload nào
