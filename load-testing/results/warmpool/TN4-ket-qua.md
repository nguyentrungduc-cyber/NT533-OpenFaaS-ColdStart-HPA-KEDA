# TN4 – Hiệu quả của Warm-Pool (Kết quả)

**Profile:** spike | **C=40** (160 req/s đỉnh) | **k6 timeout:** 10s  
**Autoscaler:** tắt (`alertmanager.create=false`) | **HPA/KEDA:** không có  
**Node taint:** `k3s-master NoSchedule` → tất cả pod fibonacci trên worker

## Bảng 7 – Kết quả đo theo số pod warm-pool

| Warm-pool (pod) | p95 Latency | Error Rate | Pod Restart trong đo | Ghi chú |
|---|---|---|---|---|
| 1 | ~10 000 ms (timeout) | 30.49% | Có (2 lần) | Queue waitress đầy, exec_timeout 30s kill process; run2 |
| 2 | 185 ms | 0% | Không | run3 (summary: warmpool_spike_run3.summary.json) |
| 3 | 17 ms | 0% | Không | run4 (summary: warmpool_spike_run4.summary.json) |

## Chi tiết

### Mức 1 pod (run2 – 2026-11-20)
- p95: ~10 000 ms (k6 timeout 10s)
- Error: 30.49% (dropped do timeout)
- Pod restart: 2 (of-watchdog exec_timeout=30s kill Python khi queue đầy)
- Nguyên nhân: 160 req/s vào 1 pod, waitress queue depth ~50, request chờ >10s

### Mức 2 pod (run3 – 2026-11-20)
- p95: 185 ms | p90: 124 ms | avg: 46 ms
- Error: 0% (22829/22829 thành công)
- Pod restart: 0
- File: `warmpool_spike_run3.summary.json`

### Mức 3 pod (run4 – 2026-11-21)
- p95: 17 ms | p90: 14 ms | avg: 10 ms
- Error: 0% (22829/22829 thành công)
- Pod restart: 0
- File: `warmpool_spike_run4.summary.json`

## Nhận xét

1 pod không đủ xử lý spike 160 req/s — queue đầy, timeout tràn lan.  
2 pod đã đủ để xử lý tải (0% lỗi), p95 giảm từ 10s xuống 185ms.  
3 pod tiếp tục cải thiện p95 xuống 17ms — headroom tốt.  
Warm-pool hiệu quả rõ: tăng pod sẵn sàng loại bỏ hoàn toàn lỗi timeout.
