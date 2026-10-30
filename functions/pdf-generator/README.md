# Function: pdf-generator

**Trạng thái:** ⬜ Chưa triển khai

TODO (Người 2): Copy cấu trúc từ `../hello-world/` làm mẫu:
- `handler.py` (hoặc ngôn ngữ khác) — logic xử lý chính
- `pdf-generator.yml` — OpenFaaS function definition
- `requirements.txt` (nếu Python) hoặc `package.json` (nếu Node)

Trong `pdf-generator.yml` nhớ:
- `image: ghcr.io/nguyentrungduc-cyber/pdf-generator:latest`
- nhãn `com.openfaas.scale.factor: "0"` (tắt bộ co giãn có sẵn của OpenFaaS)
- khai báo template trong mục `configuration.templates`, **phải có cả `name` và `source`** (copy từ `../hello-world/hello-world.yml`), thiếu `source` thì GitHub Actions báo lỗi `The repository URL must be a valid git repo uri`

Scale-to-zero làm bằng KEDA (xem `../../autoscaling/keda/`), không dùng nhãn
`com.openfaas.scale.zero` vì nhãn đó chỉ có tác dụng ở bản OpenFaaS trả phí.
