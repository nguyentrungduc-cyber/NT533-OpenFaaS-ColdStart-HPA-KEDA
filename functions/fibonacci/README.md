# fibonacci

Mục đích: tạo tải CPU điều chỉnh được để thử autoscaling (HPA vs KEDA).

Đầu vào: một số nguyên n trong body (mặc định 30, tối đa 100000; n âm hoặc không phải số trả 400).

Đầu ra: JSON {"n": ..., "bits": ..., "elapsed_ms": ...}
- bits: số bit của Fibonacci(n), thay cho số chữ số vì Python 3.11+ không đổi số quá 4300 chữ số sang chuỗi
- elapsed_ms: thời gian tính toán thuần bên trong function

Gọi mẫu: curl -d 50000 http://192.168.243.10:31112/function/fibonacci