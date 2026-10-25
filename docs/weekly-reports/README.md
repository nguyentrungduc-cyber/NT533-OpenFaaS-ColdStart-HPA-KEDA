# Weekly Reports — Kế hoạch & Báo cáo tiến độ 15 tuần

## Timeline tổng quan

| Tuần | Nội dung | Người phụ trách chính | Trạng thái |
|---|---|---|---|
| 1-2 | Tìm hiểu lý thuyết: container, Kubernetes, serverless, cold-start, HPA/KEDA. Viết đề cương chi tiết | Cả nhóm | ✅ Đã xong |
| 3-4 | Dựng 4 VM, cài Ubuntu Server 22.04, cấu hình mạng nội bộ (host-only 192.168.243.0/24) | Người 1 | ✅ Đã xong |
| 5-6 | Cài k3s cluster (1 control-plane + 3 worker), kiểm tra kết nối, cài metrics-server | Người 1 | ✅ Đã xong |
| 7-8 | Cài OpenFaaS trên cluster, viết & deploy function demo, cấu hình scale-to-zero | Người 2 (Người 1 đã cài nền trước) | ✅ OpenFaaS + KEDA cài sẵn; functions đang viết |
| 9 | Cấu hình HPA, cấu hình KEDA, kiểm thử scale thủ công cho cả hai | Người 3 | ⬜ Chờ functions từ Người 2 |
| 10 | Triển khai Prometheus + Grafana, tích hợp metrics từ OpenFaaS & K8s | Người 4 (Người 1 đã cài nền trước) | ✅ Stack cài sẵn; dashboard cần hoàn thiện |
| 11 | Thử nghiệm các chiến lược tối ưu cold-start (warm-pool, image nhẹ, probe), đo latency | Người 2, 3 | ⬜ |
| 12 | Chạy load test song song trên HPA và KEDA, thu thập số liệu so sánh | Người 3 | ⬜ |
| 13 | Tổng hợp số liệu; vẽ biểu đồ so sánh cold-start và HPA vs KEDA | Người 3, 4 | ⬜ |
| 14 | Hoàn thiện báo cáo, chuẩn bị demo trực tiếp | Cả nhóm | ⬜ |
| 15 | Bảo vệ đồ án | Cả nhóm | ⬜ |

> **Ghi chú tuần 7-10:** Người 1 đã cài sẵn toàn bộ nền tảng (OpenFaaS, KEDA,
> Prometheus, Grafana, Tailscale) trước schedule. Người 2, 3, 4 chỉ cần thao tác
> phần được giao mà không cần đụng tới hạ tầng. Xem nhật ký chi tiết tại
> [`week-03-10.md`](./week-03-10.md).

## Cách dùng thư mục này

Mỗi tuần (hoặc mỗi mốc quan trọng), tạo 1 file báo cáo ngắn:

```
docs/weekly-reports/week-03-04.md
docs/weekly-reports/week-05-06.md
...
```

Mỗi file ghi:
- Việc đã làm được (link tới commit/PR liên quan)
- Vấn đề gặp phải + cách xử lý
- Việc còn lại / chuyển giao cho tuần sau

## Template file báo cáo tuần

```markdown
# Tuần X-Y — <Tên nội dung>

**Người phụ trách:** ...
**Ngày:** ...

## Đã làm
- ...

## Vấn đề gặp phải
- ...

## Việc còn lại
- ...
```
