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

**Không** đặt nhãn `com.openfaas.scale.factor: "0"` cho function. Gateway OpenFaaS CE
0.27.x coi giá trị 0 là không hợp lệ, mọi lần gọi function đều trả về:

```
404 - error finding function <tên>.openfaas-fn: bad scaling factor: 0, is not in range of [0 - 100]
```

Việc bộ co giãn có sẵn của OpenFaaS CE có tranh quyền với HPA/KEDA hay không sẽ được
kiểm chứng ở bước thử scale-to-zero (tạo tải khi chưa gắn HPA/KEDA, xem số pod có tự tăng
không). Nếu có, Người 1 tắt ở cấu hình chung bằng `helm upgrade`, không dùng nhãn trên từng function.

## Liên kết với Cold-start Optimization

Sau khi function chạy ổn định, các thử nghiệm tối ưu cold-start latency
được thực hiện tại [`../coldstart-optimization/`](../coldstart-optimization/)
— dùng chính các function này làm đối tượng đo.
