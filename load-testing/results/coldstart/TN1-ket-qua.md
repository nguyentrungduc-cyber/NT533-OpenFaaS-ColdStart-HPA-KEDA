# TN1 — Cold-start theo runtime: Python so với Node.js

**Ngày đo:** 17/11/2026
**Người chạy:** Nguyễn Trung Đức (Người 1), trên tài khoản `tranduc` ở máy master
**Commit / image:** `9aaddd3` (`latest-9aaddd3`), `imagePullPolicy: IfNotPresent`
**Công cụ:** `load-testing/coldstart.sh`, 31 lần mỗi function, bỏ lần đầu
**Định nghĩa cold-start:** thời gian từ lúc ra lệnh tăng thêm 1 pod tới khi pod mới Ready
(xem `load-testing/results/scale-to-zero-test.md` để biết vì sao không đo theo nghĩa kinh điển)

## Kết luận

Python và Node.js **không khác nhau có ý nghĩa**: chênh 31 ms, nhỏ hơn sai số phép đo,
t ≈ 0,98. Hai khoảng tin cậy 95% của mean chồng lên nhau gần hết.

## Số liệu

| Chỉ số (30 lần, bỏ lần đầu) | fibonacci (Python) | data-transform (Node.js) |
| --- | --- | --- |
| Mean | 3592 ms | 3562 ms |
| Khoảng tin cậy 95% của mean | 3549–3635 ms | 3514–3609 ms |
| Median | 3643 ms | 3567 ms |
| Min – max | 3356 – 3699 ms | 3382 – 3772 ms |
| p95 | 3694 ms | 3724 ms |
| Độ lệch chuẩn | 114 ms | 126 ms |
| Lần đầu (đã bỏ) | 3105 ms | 15288 ms |
| Node | worker1 cả 31 lần | worker3 cả 31 lần |

Kiểm định: hiệu hai mean = 30,8 ms, sai số chuẩn của hiệu = 31,5 ms, t ≈ 0,98.

File thô:
- `fibonacci-20261117-054958.csv` (+ `.meta`)
- `data-transform-20261117-060037.csv` (+ `.meta`)

## Diễn giải

Với định nghĩa scale-out, ~3,6 giây chủ yếu là phần việc của Kubernetes: xếp lịch pod, tạo
container, chờ readiness probe. Thời gian runtime tự khởi động (Python hay Node.js) quá nhỏ so
với phần đó nên không lộ ra trong số đo. Hàm ý: muốn giảm cold-start thì nên nhắm vào kích
thước image và cấu hình probe (TN2, TN3) hơn là đổi ngôn ngữ.

## Lần đo đầu của data-transform: 15,3 giây, do kéo image

Đã kiểm chứng bằng event Kubernetes (file `tn1-data-transform-pull-events-20261117.txt`):
pod đầu tiên của lượt đo (`data-transform-686869bfb8-2vvm2`) rơi vào worker3, node này chưa có
image `latest-9aaddd3` nên phải kéo về:

```
Pulling image ".../data-transform:latest-9aaddd3"
Successfully pulled ... in 12.368s. Image size: 73022216 bytes
```

15,3 − 12,4 ≈ 2,9 giây còn lại, gần với các lần bình thường. Các lần sau event ghi
`already present on machine`.

Đây là lý do quy ước "bỏ lần đầu" được giữ: lần đầu có thể dính việc kéo image, thứ TN1 không
đo. Giữ lần đầu thì mean data-transform nhảy từ 3562 lên 3940 ms, độ lệch chuẩn từ 126 lên
2076 ms. Với fibonacci (image đã có sẵn) thì gần như không đổi: 3592 so với 3577 ms.

## Thời gian kéo image dao động rất lớn

Cũng file event đó ghi các lần kéo cùng image ~73 MB trong 5 ngày: 83,0 s; 49,9 s; 25,9 s;
12,4 s; và 1,0–2,7 s. Có thêm hai lần thất bại (`lookup ghcr.io: Try again`,
`connection refused`). Hệ quả cho TN3:

- 5 lần mỗi trường hợp là không đủ; nên báo median kèm min–max, hoặc tăng số lần.
- Các lần 1–2,7 s nhiều khả năng do lớp image dùng chung đã có sẵn. Trước mỗi lần đo "phải kéo",
  xoá mọi tag của image trên cả 3 worker và đối chiếu thời gian kéo trong event.

## Quan sát chưa giải thích

Số đo tách thành hai cụm cách nhau ~250 ms (~3,4 s và ~3,65 s). Với fibonacci, lần thấp rơi đều
đặn ở lần 4, 9, 14, 19, 23, 27, 31. Khoảng cách này nằm trong sai số vài trăm ms của vòng kiểm
tra 0,2 giây trong script, nên chưa kết luận gì. Nguyên nhân chưa kiểm.

## Hạn chế

- Mỗi function được xếp vào đúng một node suốt 31 lần, nên số liệu không phản ánh khác biệt giữa
  các node.
- Sai số mỗi số đo cỡ vài trăm ms (vòng kiểm tra 0,2 s + thời gian chạy `kubectl`).
- Đo trên một cụm máy ảo trong một laptop; số tuyệt đối không dùng để so với hệ thống khác.
