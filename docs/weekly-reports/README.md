# Weekly Reports — Kế hoạch & Báo cáo tiến độ 15 tuần

## Timeline tổng quan (từ đề cương)

| Tuần | Nội dung | Người phụ trách chính | Trạng thái |
|---|---|---|---|
| 1-2 | Tìm hiểu lý thuyết: container, Kubernetes, serverless, cold-start, HPA/KEDA. Viết đề cương chi tiết | Cả nhóm | ✅ Đã xong (đề cương này) |
| 3-4 | Dựng 4 VM, cài Ubuntu Server, cấu hình mạng nội bộ giữa các node | Người 1 | ⬜ |
| 5-6 | Cài k3s cluster (1 control-plane + 3 worker), kiểm tra kết nối, cài metrics-server | Người 1, 3 | ⬜ |
| 7-8 | Cài OpenFaaS trên cluster, viết & deploy 5 function demo, cấu hình scale-to-zero | Người 2 | ⬜ |
| 9 | Cấu hình HPA, cấu hình KEDA, kiểm thử scale thủ công cho cả hai | Người 3 | ⬜ |
| 10 | Triển khai Prometheus + Grafana, tích hợp metrics từ OpenFaaS & K8s | Người 4 | ⬜ |
| 11 | Thử nghiệm các chiến lược tối ưu cold-start (warm-pool, image nhẹ, probe), đo latency | Người 2, 3 | ⬜ |
| 12 | Chạy load test song song trên HPA và KEDA, thu thập số liệu so sánh | Người 3 | ⬜ |
| 13 | Tổng hợp số liệu; vẽ biểu đồ so sánh cold-start và HPA vs KEDA | Người 3, 4 | ⬜ |
| 14 | Hoàn thiện báo cáo, chuẩn bị demo trực tiếp | Cả nhóm | ⬜ |
| 15 | Bảo vệ đồ án | Cả nhóm | ⬜ |

## Cách dùng thư mục này

Mỗi tuần (hoặc mỗi mốc quan trọng), tạo 1 file báo cáo ngắn:

```
docs/weekly-reports/week-03-04.md
docs/weekly-reports/week-05-06.md
...
```

Mỗi file nên ghi:
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
