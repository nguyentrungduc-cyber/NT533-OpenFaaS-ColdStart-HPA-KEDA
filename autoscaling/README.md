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

## Thông số đã đo (fibonacci)

**Nhãn function trong Prometheus** (dùng cho query KEDA): `function_name="fibonacci.openfaas-fn"`
(có hậu tố namespace; thiếu hậu tố thì query rỗng, KEDA không scale mà cũng không báo lỗi).
`gateway_service_count` cũng có sẵn cho từng function (số pod).

**Sức chịu C của 1 pod: C = 40 req/s.** Đo ngày 18/11/2026 bằng
[`calibrate.js`](../load-testing/k6-scripts/calibrate.js) (arrival-rate, mỗi mức 1 phút, N=20000),
trên master, fibonacci giữ 1 pod (requests cpu 100m, limits cpu 500m), không gắn HPA/KEDA.
Tiêu chí chọn C: mức cao nhất mà p95 còn ở mức nền (khoảng 13 ms).

| Mức tải (req/s) | p95 | Tỷ lệ lỗi | CPU pod (đỉnh) |
|---|---|---|---|
| 10 | 13,27 ms | 0% | chưa ghi |
| 20 | 14,87 ms | 0% | chưa ghi |
| 40 | 13,22 ms | 0% | chưa ghi |
| 50 | 73,6 ms | 0% | chưa ghi |
| 60 | 376 ms | 0% | 472m |
| 70 | 20,59 s | 3,38% | 501m |
| 80 | 30 s | 6,92% | 501m |

Từ mức 60 CPU pod chạm sát limit 500m, cùng lúc p95 và lỗi tăng: nút thắt là CPU limit của pod.
Ở mức 80 k6 chạm trần 400 VU, tải thực gửi ra thấp hơn mức yêu cầu.
Hạn chế: mới đo 1 lần; k6 chạy trên master nên cạnh tranh CPU với cụm.
