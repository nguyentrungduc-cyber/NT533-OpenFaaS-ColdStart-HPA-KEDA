# fibonacci

Mục đích: tạo tải CPU điều chỉnh được để thử autoscaling (HPA vs KEDA).

Đầu vào: một số nguyên n trong body (mặc định 30). n lớn hơn 100000 bị giới hạn về 100000
(không báo lỗi); n âm hoặc không phải số nguyên trả 400.

Đầu ra: JSON

```json
{"n": ..., "bits": ..., "elapsed_ms": ...}
```

- `bits`: số bit của Fibonacci(n), thay cho số chữ số vì Python 3.11+ không đổi số quá 4300 chữ số sang chuỗi
- `elapsed_ms`: thời gian tính toán thuần bên trong function

Gọi mẫu:

```bash
curl -d 50000 http://192.168.243.10:31112/function/fibonacci
```
