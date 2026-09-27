# Functions — Serverless Platform (Người 2)

## Mục tiêu

Cài đặt OpenFaaS Gateway trên cluster, viết tối thiểu 5 serverless
functions minh họa, cấu hình scale-to-zero.

## Danh sách function (theo đề cương — tối thiểu 5)

| Function | Mục đích | Trạng thái |
|---|---|---|
| `hello-world` | Function demo tối thiểu, dùng test nhanh gateway/scale-to-zero | ⬜ Chưa làm |
| `image-processing` | Xử lý ảnh (resize/filter...) | ⬜ Chưa làm |
| `email-sender` | Gửi email | ⬜ Chưa làm |
| `data-processor` | Xử lý dữ liệu | ⬜ Chưa làm |
| `pdf-generator` | Tạo PDF | ⬜ Chưa làm |

## Cấu trúc mỗi function (chuẩn OpenFaaS)

```
functions/<ten-function>/
├── handler.<ext>       # Logic xử lý chính
├── requirements.txt     # (nếu Python) hoặc package.json (nếu Node)
└── <ten-function>.yml   # OpenFaaS function definition
```

## Cách deploy (điền khi hoàn thành)

```bash
faas-cli build -f hello-world.yml
faas-cli push -f hello-world.yml
faas-cli deploy -f hello-world.yml
```

## Cấu hình scale-to-zero

Mỗi function cần set trong file `.yml`:
```yaml
labels:
  com.openfaas.scale.zero: "true"
  com.openfaas.scale.min: "0"
  com.openfaas.scale.max: "5"
```

## Liên kết với Cold-start Optimization

Sau khi function chạy ổn định, các thử nghiệm tối ưu cold-start latency
được thực hiện tại [`../coldstart-optimization/`](../coldstart-optimization/)
— dùng chính các function này làm đối tượng đo.
