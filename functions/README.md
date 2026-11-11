# Functions — Serverless Platform (Người 2)

## Mục tiêu

Cấu hình OpenFaaS Gateway (Người 1 đã cài sẵn trên cluster), viết tối thiểu 5
serverless functions minh họa, cấu hình scale-to-zero.

## Danh sách function (đề cương yêu cầu tối thiểu 5, hiện có 6)

| Function | Mục đích | Khai báo ở | Trạng thái |
|---|---|---|---|
| `hello-world` | Function demo tối thiểu, test nhanh gateway, baseline đo cold-start | `hello-world/hello-world.yml` | ✅ Code sẵn sàng |
| `hello-py` | Function demo trả về chuỗi cố định | `stack.yml` | ✅ Code sẵn sàng |
| `fibonacci` | Tạo tải CPU điều chỉnh được, dùng thử HPA vs KEDA | `stack.yml` | ✅ Code sẵn sàng |
| `text-sentiment` | Phân tích cảm xúc văn bản, function nhẹ để đo throughput | `stack.yml` | ✅ Code sẵn sàng |
| `notify` | Mô phỏng gửi thông báo (chỉ ghi log, không gửi email thật) | `stack.yml` | ✅ Code sẵn sàng |
| `image-resize` | Resize ảnh bằng Pillow, image lớn, tốn CPU (TN2, TN3) | `stack.yml` | ✅ Code sẵn sàng |
| `data-transform` | Biến đổi/lọc/cộng bản ghi JSON; Node.js, để đối chiếu cold-start với Python (TN1) | `stack.yml` | ✅ Code sẵn sàng |

Bốn thư mục `image-processing`, `email-sender`, `data-processor`, `pdf-generator` trước
đây chỉ có README hướng dẫn, chưa từng được triển khai, nay đã xoá. `notify` thay cho
`email-sender` và `image-resize` thay cho `image-processing`.

Chi tiết đầu vào/đầu ra của từng function xem `README.md` trong thư mục của function đó.

## Cấu trúc mỗi function (chuẩn OpenFaaS)

```
functions/<ten-function>/
├── handler.<ext>       # Logic xử lý chính
├── requirements.txt     # (nếu Python) hoặc package.json (nếu Node)
└── <ten-function>.yml   # OpenFaaS function definition (handler: ./<ten-function>)
```

Có 2 cách khai báo function, workflow build nhận cả hai:

- Mỗi function một file `functions/<ten-function>/<ten-function>.yml` (như `hello-world`)
- Gom chung vào `functions/stack.yml` (như `hello-py`, `fibonacci`, `text-sentiment`,
  `notify`, `image-resize`); khi đó thư mục function không cần file `.yml` riêng

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

Các function khai báo trong `stack.yml` deploy cùng lúc (vẫn từ thư mục `functions/`):

```bash
faas-cli deploy -f stack.yml --tag sha
# hoặc chỉ một function:
faas-cli deploy -f stack.yml --filter fibonacci --tag sha
```

`--tag sha` gắn mã commit vào tên image, nên phải `git pull` đúng commit mà Actions vừa build.

Phương án dự phòng (laptop có Docker Desktop), cũng chạy từ `functions/`:

```bash
faas-cli up -f hello-world/hello-world.yml --tag sha
```

## Scale-to-zero

OpenFaaS bản CE (bản đang dùng) **không có** scale-to-zero lẫn scale-from-zero. Đã kiểm
chứng bằng thực nghiệm: faas-netes tự đưa function về lại 1 pod trong vài giây, không cần
có request nào, và mỗi function bị giới hạn tối đa 5 pod. Nhãn `com.openfaas.scale.zero`
chỉ có tác dụng ở bản trả phí.

Dùng KEDA với `minReplicaCount: 0` **cũng không được**: KEDA và faas-netes giằng co, có
khoảng 2 phút liền không pod nào sẵn sàng phục vụ. Mọi HPA và ScaledObject trong đồ án
phải đặt số pod tối thiểu là 1 và tối đa là 5.

Bằng chứng đầy đủ: [`../load-testing/results/scale-to-zero-test.md`](../load-testing/results/scale-to-zero-test.md).

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
