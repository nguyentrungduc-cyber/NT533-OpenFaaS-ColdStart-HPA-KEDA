# TN3 — Cold-start khi phải kéo image: Alpine so với Debian slim

**Ngày đo:** 19/11/2026 (khoảng 17:40–18:25 giờ Việt Nam)
**Người chạy:** Nguyễn Trung Đức (Người 1), trên tài khoản `tranduc` ở máy master
**Commit / image:** `ea92143` (`latest-5ee7c6f`), `imagePullPolicy: IfNotPresent`
**Công cụ:** `load-testing/coldstart.sh`, 2 lần mỗi lượt (chỉ lấy lần 1); 5 lượt mỗi image
**Định nghĩa cold-start:** thời gian từ lúc ra lệnh tăng thêm 1 pod tới khi pod mới Ready

## Kết luận

Khi node **chưa có image**, kích thước image **có ảnh hưởng lớn** tới cold-start:
image Debian lớn gấp 3,4 lần (125 MB so với 36 MB) → cold-start dài gấp ~4,8 lần
(median 76,7 giây so với 16,1 giây). Phần lớn chênh lệch nằm ở thời gian kéo image
(median 68,8 s so với 12,9 s, chênh 5,3 lần). Kết hợp với TN2 (khi image có sẵn,
chênh chỉ 24 ms), rõ ràng kích thước image chỉ ảnh hưởng qua thời gian kéo về node —
sau khi đã cache thì không còn ý nghĩa.

## Điều kiện đo

Trước mỗi lượt đo, xóa toàn bộ tag của cả hai image trên cả 3 worker bằng
`delete-images.sh` (dùng `crictl rmi`). Sau khi xác nhận `crictl images` không còn
dòng nào khớp với `fibonacci` hoặc `fib-debian`, mới chạy `coldstart.sh`.

Mỗi lượt chạy 2 lần: lần 1 phải kéo image (số liệu TN3), lần 2 xác nhận image đã cache
(nên trở về ~3,5 giây). Chỉ lần 1 được dùng trong bảng dưới.

## Số liệu — fibonacci (Alpine, 36,3 MB)

Tất cả 5 lần pod mới rơi vào k3s-worker3.

| Lượt | Cold-start (ms) | Pull time (event kubelet) | Ghi chú |
| --- | --- | --- | --- |
| 1 | 16.127 | 13,885 s | |
| 2 | 16.627 | 12,618 s | |
| 3 | 16.137 | 13,893 s | |
| 4 | 17.041 | 12,692 s | |
| 5 | 14.939 | 12,856 s | |

| Chỉ số | Cold-start | Pull time |
| --- | --- | --- |
| Median | **16.137 ms** | **12,856 s** |
| Min | 14.939 ms | 12,618 s |
| Max | 17.041 ms | 13,893 s |
| Mean | 16.174 ms | 13,189 s |

## Số liệu — fib-debian (Debian slim-bookworm, 125,0 MB)

Tất cả 5 lần pod mới rơi vào k3s-worker1.

| Lượt | Cold-start (ms) | Pull time (event kubelet) | Ghi chú |
| --- | --- | --- | --- |
| 1 | 73.240 | 68,758 s | |
| 2 | 78.125 | 75,626 s | |
| 3 | 99.171 | 64,650 s | Có 1 lần kéo thất bại (connection refused) trước khi thành công; cold-start cao hơn do chờ retry |
| 4 | 70.791 | 68,526 s | |
| 5 | 76.700 | 73,544 s | |

| Chỉ số | Cold-start | Pull time |
| --- | --- | --- |
| Median | **76.700 ms** | **68,758 s** |
| Min | 70.791 ms | 64,650 s |
| Max | 99.171 ms | 75,626 s |
| Mean (tất cả 5) | 79.605 ms | 70,221 s |
| Mean (bỏ lần 3) | 74.714 ms | 71,614 s |

Lần 3 (99.171 ms) là outlier có giải thích: event ghi nhận một lần kéo thất bại
(`connection refused` tới ghcr.io) trước khi kéo thành công trong 64,65 s. Thời gian
chờ backoff và retry (~22 giây thêm) giải thích toàn bộ chênh lệch so với median.
Hiện tượng mạng chập chờn tương tự đã thấy ở TN1 và TN2.

## So sánh tổng hợp

| | fibonacci (Alpine) | fib-debian (Debian slim) | Tỉ lệ |
| --- | --- | --- | --- |
| Kích thước image | 36,3 MB | 125,0 MB | 3,44× |
| Pull time (median) | 12,856 s | 68,758 s | **5,35×** |
| Cold-start khi kéo (median) | 16.137 ms | 76.700 ms | **4,75×** |
| Cold-start khi có sẵn (TN2) | 3.521 ms | 3.497 ms | 1,0× |
| Thêm do kéo image (median) | ≈ 12.616 ms | ≈ 73.203 ms | 5,8× |

Pull time chênh 5,35 lần trong khi kích thước chênh 3,44 lần. Điều này có thể do
tỉ lệ nén của hai image khác nhau (Alpine có nhiều layer nhỏ, Debian có layer base lớn),
hoặc overhead của containerd khi giải nén layer lớn. Chưa kiểm chứng nguyên nhân cụ thể.

## Đối chiếu với baseline (image có sẵn)

| Trường hợp | fibonacci | fib-debian |
| --- | --- | --- |
| Image có sẵn (TN2, median) | 3.521 ms | 3.497 ms |
| Phải kéo image (TN3, median) | 16.137 ms | 76.700 ms |
| Chênh lệch | +12.616 ms (+358%) | +73.203 ms (+2093%) |

Với fibonacci (image nhỏ), cold-start khi kéo dài gấp 4,6 lần so với khi có sẵn — vẫn
trong tầm chịu được (16 giây). Với fib-debian (image lớn), cold-start khi kéo dài gấp
21,9 lần — 76 giây là mức không chấp nhận được trong hầu hết ứng dụng thực tế.

## Hạn chế

- fibonacci luôn rơi worker3, fib-debian luôn rơi worker1 → kết quả lẫn yếu tố node.
  Mức chênh do node (từ TN1/TN2) ước khoảng 70 ms, nhỏ so với chênh lệch TN3 nên
  không ảnh hưởng kết luận.
- Mạng từ cụm ra ghcr.io không ổn định (3 lần thất bại trong tổng số 10 lần kéo),
  làm pull time biến động.
- Chỉ so hai image nền; không đo distroless hay scratch.
- Chỉ 5 lần mỗi image; range pull time fib-debian khá rộng (65–76 s).
- k6 / lệnh khác chạy trên master có thể cạnh tranh CPU với cụm.

## File thô

Mỗi file CSV chứa 2 dòng (lần 1 và lần 2); chỉ lần 1 dùng cho TN3.

**fibonacci:**
- `fibonacci-20261119-104005.csv` (lượt 1)
- `fibonacci-20261119-104349.csv` (lượt 2)
- `fibonacci-20261119-105010.csv` (lượt 3)
- `fibonacci-20261119-105218.csv` (lượt 4)
- `fibonacci-20261119-105432.csv` (lượt 5)

**fib-debian:**
- `fib-debian-20261119-111125.csv` (lượt 1)
- `fib-debian-20261119-111435.csv` (lượt 2)
- `fib-debian-20261119-111749.csv` (lượt 3)
- `fib-debian-20261119-112125.csv` (lượt 4)
- `fib-debian-20261119-112433.csv` (lượt 5)
