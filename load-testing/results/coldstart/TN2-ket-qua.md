# TN2 — Cold-start theo kích thước image: Alpine so với Debian slim

**Ngày đo:** 18/11/2026 (khoảng 23:46–23:53 giờ Việt Nam)
**Người chạy:** Nguyễn Trung Đức (Người 1), trên tài khoản `tranduc` ở máy master
**Commit / image:** `5ee7c6f` (`latest-5ee7c6f`), `imagePullPolicy: IfNotPresent`
**Công cụ:** `load-testing/coldstart.sh`, 31 lần mỗi function, bỏ lần đầu
**Định nghĩa cold-start:** thời gian từ lúc ra lệnh tăng thêm 1 pod tới khi pod mới Ready
(xem `load-testing/results/scale-to-zero-test.md` để biết vì sao không đo theo nghĩa kinh điển)

## Kết luận

Khi image **đã có sẵn trên node**, kích thước image **không ảnh hưởng** tới cold-start:
image Debian lớn gấp 3,4 lần nhưng chênh chỉ 24 ms, nhỏ hơn sai số phép đo, t ≈ 0,95.
Kích thước image chỉ có thể tạo khác biệt khi phải kéo image về node, là nội dung của TN3.

## Hai bản được so sánh

Chỉ khác nhau ở image nền; mã nguồn, phiên bản Python, watchdog và tài nguyên giống hệt.

| | fibonacci | fib-debian |
| --- | --- | --- |
| Template OpenFaaS | `python3-http` | `python3-http-debian` |
| Image nền | `python:3.12-alpine` | `python:3.12-slim-bookworm` |
| Mã nguồn | `functions/fibonacci` | `functions/fibonacci` (dùng chung) |
| Watchdog | `of-watchdog 0.12.5` | `of-watchdog 0.12.5` |
| `requests` / `limits` CPU | 350m / 500m | 350m / 500m |
| **Kích thước image** | **36,3 MB** (36.317.967 byte) | **125,0 MB** (125.049.508 byte) |

Nguồn kích thước: `tn2-image-sizes-20261118.txt` (đọc từ `status.images` của từng node).
Phiên bản Python và watchdog: đối chiếu Dockerfile của hai template trong
`openfaas/python-flask-template`. `requests` của fib-debian được đổi từ 100m lên 350m (PR #13)
để khớp với fibonacci trước khi đo.

## Số liệu

| Chỉ số (30 lần, bỏ lần đầu) | fibonacci (Alpine) | fib-debian (Debian slim) |
| --- | --- | --- |
| Mean | 3521 ms | 3497 ms |
| Khoảng tin cậy 95% của mean | 3495–3546 ms | 3453–3541 ms |
| Median | 3514 ms | 3518 ms |
| Min – max | 3297 – 3721 ms | 3271 – 3749 ms |
| p95 | 3625 ms | 3649 ms |
| Độ lệch chuẩn | 69 ms | 118 ms |
| Lần đầu (đã bỏ) | 2978 ms | 2934 ms |
| Node | worker3 cả 31 lần | worker1 cả 31 lần |

Kiểm định Welch: hiệu hai mean = 23,7 ms, sai số chuẩn của hiệu = 25,0 ms, t ≈ 0,95,
khoảng tin cậy 95% của hiệu từ −27 đến +74 ms (chứa 0).

Độ lệch chuẩn trong bảng dùng công thức chia cho n − 1. Phần tổng kết `coldstart.sh` in ra
chia cho n nên thấp hơn một chút (67,6 và 116,5 ms).

File thô:
- `fibonacci-20261118-164608.csv` (+ `.meta`)
- `fib-debian-20261118-164948.csv` (+ `.meta`)

## Kiểm soát việc kéo image

Muốn TN2 chỉ đo trường hợp image có sẵn, nên trước khi đo cả hai image `latest-5ee7c6f` được
kéo sẵn lên cả 3 worker bằng pod tạm gắn vào từng node. `tn2-image-sizes-20261118.txt` xác nhận
cả 3 worker có đủ hai image.

`tn2-pull-events-20261118.txt` ghi mọi lần kéo image còn trong event Kubernetes. Tất cả xảy ra
**trước** giờ đo (lúc deploy và kéo sẵn, khoảng 23:20–23:35), không lần đo nào dính việc kéo
image. Các lần kéo đó cũng cho số liệu tham khảo cho TN3:

| Image | Kích thước | Thời gian kéo thành công |
| --- | --- | --- |
| fibonacci `latest-5ee7c6f` | 36,3 MB | 16,9 s |
| fibonacci `latest-497bbfc` | 36,3 MB | 33,1 s |
| fib-debian `latest-5ee7c6f` | 125,0 MB | 1 phút 16,8 s; 1 phút 35,4 s |

Có thêm 3 lần kéo thất bại (`connection refused` tới ghcr.io) rồi tự thử lại thành công,
cùng hiện tượng mạng chập chờn đã thấy ở TN1.

## Diễn giải

Với định nghĩa scale-out và image đã nằm sẵn trên node, khởi động pod không phải đọc image qua
mạng, nên image 36 MB hay 125 MB đều cho cold-start khoảng 3,5 giây. Kết hợp với TN1 (đổi
runtime cũng không khác), phần lớn ~3,5 giây là việc của Kubernetes: xếp lịch, tạo container,
chờ readiness probe. Kích thước image chỉ còn ý nghĩa khi phải kéo image (một lần kéo
fib-debian mất 77–95 giây, dài gấp khoảng 20–25 lần cả lần cold-start), nên nên đưa cả hai
image vào TN3.

## Lần đo đầu thấp nhất, cả hai bản

Lần đầu là lần thấp nhất ở cả hai bản (2978 và 2934 ms), giống fibonacci ở TN1 (3105 ms).
Lần này image đã kéo sẵn, nên lý do "lần đầu dính việc kéo image" của TN1 không áp dụng.
Kết quả không đổi dù giữ hay bỏ lần đầu:

| | fibonacci | fib-debian |
| --- | --- | --- |
| Mean, bỏ lần đầu (30) | 3521 ms | 3497 ms |
| Mean, giữ lần đầu (31) | 3503 ms | 3479 ms |

Nguyên nhân lần đầu thấp hơn chưa kiểm.

## Lần đo dở

`fib-debian-20261118-094326-DUT-GIUA-CHUNG.csv` là lượt đo chiều 18/11, dừng sau 12/31 lần vì
tắt máy, đo với `requests` 100m và image `latest-497bbfc`. Giữ lại để đối chiếu, **không dùng**
trong bảng trên. 12 lần đó nằm trong 3210–3759 ms, cùng mức với lượt đo chính thức.

## Hạn chế

- Mỗi bản rơi trọn vào một node khác nhau (fibonacci ở worker3, fib-debian ở worker1), nên kết
  quả lẫn yếu tố node. Mức chênh do node ước lượng được từ fibonacci: 3592 ms trên worker1
  (TN1, 17/11) so với 3521 ms trên worker3 (TN2), cỡ 70 ms, cùng cỡ với chênh lệch TN2.
- Sai số mỗi số đo cỡ vài trăm ms (vòng kiểm tra 0,2 s + thời gian chạy `kubectl`).
- Chỉ so hai image nền; không thử image tối giản hơn (distroless, scratch).
- Đo trên một cụm máy ảo trong một laptop; số tuyệt đối không dùng để so với hệ thống khác.
