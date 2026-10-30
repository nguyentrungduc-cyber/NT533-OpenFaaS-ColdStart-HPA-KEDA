# Functions — Serverless Platform (Người 2)

## Mục tiêu

Cài đặt OpenFaaS Gateway trên cluster, viết tối thiểu 5 serverless
functions minh họa, cấu hình scale-to-zero.

## Danh sách function (theo đề cương — tối thiểu 5)

| Function | Mục đích | Trạng thái |
|---|---|---|
| `hello-world` | Function demo tối thiểu, dùng test nhanh gateway/scale-to-zero | ✅ Code sẵn sàng |
| `image-processing` | Xử lý ảnh (resize/filter...) | ⬜ Chưa làm |
| `email-sender` | Gửi email | ⬜ Chưa làm |
| `data-processor` | Xử lý dữ liệu | ⬜ Chưa làm |
| `pdf-generator` | Tạo PDF | ⬜ Chưa làm |

## Cấu trúc mỗi function (chuẩn OpenFaaS)

```
functions/<ten-function>/
├── handler.<ext>       # Logic xử lý chính
├── requirements.txt     # (nếu Python) hoặc package.json (nếu Node)
└── <ten-function>.yml   # OpenFaaS function definition (handler: ./<ten-function>)
```

## Cách build và deploy

Máy master **không có Docker** (k3s dùng containerd), nên không build image trên master.
Image được build bằng GitHub Actions (workflow `.github/workflows/build-functions.yml`)
mỗi khi push code vào `functions/` trên nhánh `main`, rồi đẩy lên GHCR
(`ghcr.io/nguyentrungduc-cyber/<tên-function>`).

Sau khi tab **Actions** báo xanh, deploy trên master. **Luôn chạy từ thư mục `functions/`**
vì faas-cli tính đường dẫn `handler` và thư mục `template/` theo thư mục hiện tại:

```bash
cd ~/NT533-OpenFaaS-ColdStart-HPA-KEDA
git pull
cd functions
faas-cli deploy -f hello-world/hello-world.yml --tag sha
faas-cli invoke hello-world <<< ""
```

`--tag sha` gắn mã commit vào tên image, nên phải `git pull` đúng commit mà Actions vừa build.

Phương án dự phòng (laptop có Docker Desktop), cũng chạy từ `functions/`:

```bash
faas-cli up -f hello-world/hello-world.yml --tag sha
```

## Scale-to-zero

OpenFaaS bản CE (bản đang dùng) **không có** tính năng tự co về 0; nhãn
`com.openfaas.scale.zero` chỉ có tác dụng ở bản trả phí. Nhóm làm scale-to-zero bằng
**KEDA** (`minReplicaCount: 0`, xem `../autoscaling/keda/`).

Mỗi function đặt nhãn sau trong file `.yml` để tắt bộ co giãn có sẵn của OpenFaaS,
tránh tranh quyền điều khiển số pod với HPA/KEDA:

```yaml
labels:
  com.openfaas.scale.factor: "0"
```

## Liên kết với Cold-start Optimization

Sau khi function chạy ổn định, các thử nghiệm tối ưu cold-start latency
được thực hiện tại [`../coldstart-optimization/`](../coldstart-optimization/)
— dùng chính các function này làm đối tượng đo.
