# Giai đoạn 2: Kiểm chứng scale-to-zero trên OpenFaaS CE

Người chạy: Trần Đức (user tranduc, từ laptop qua Tailscale)
Ngày: 01/11/2026
Điều kiện: KHÔNG phải máy đo chuẩn. Các con số thời gian chỉ để kiểm tra phương pháp, không dùng làm số liệu chính thức.

Phiên bản:
- OpenFaaS CE: gateway 0.27.14, faas-netes 0.18.17
- KEDA: ghcr.io/kedacore/keda:2.21.0
- Function thử: hello-py (branch feature/data-transform, đã bỏ nhãn com.openfaas.scale.factor)
- Trước khi thử: không có HPA hay ScaledObject nào trong namespace openfaas-fn

## Tóm tắt kết quả

| Câu hỏi | Kết quả |
| --- | --- |
| Function có giữ được ở 0 pod không? | Không. faas-netes tự đưa về 1 pod trong vài giây, không cần request |
| faas-netes có chặn việc tăng pod không? | Không. Tăng lên 3 pod giữ nguyên sau 60 giây |
| Bộ co giãn có sẵn của CE có tự tăng pod khi tải cao? | CÓ, 3/4 14:49:52 |
| KEDA minReplicaCount 0 hoạt động thế nào? | Không co về 0 được; giằng co với faas-netes, khoảng 2 phút liền không có pod nào sẵn sàng. Phải đặt minReplicaCount >= 1 |
| Thời gian tạo 1 pod mới tới khi sẵn sàng (thử 3 lần) | Lan 1: 5343 ms, Lan 2: 3011 ms, Lan 3: 2985 ms |

## 1. Hạ về 0 bị kéo lên lại

Lệnh `kubectl -n openfaas-fn scale deployment hello-py --replicas=0`, sau đó pod mới xuất hiện ngay, trước khi gọi request nào.
Lần đo `time curl` ngay sau đó ra 0.009 s: pod đã chạy sẵn, KHÔNG phải cold-start, không dùng con số này.

Events của Deployment:

```
Normal  ScalingReplicaSet  5m41s                  deployment-controller  Scaled down replica set hello-py-6549c8d5 from 1 to 0
Normal  ScalingReplicaSet  3m56s (x2 over 6m35s)  deployment-controller  Scaled up replica set hello-py-c7c46d79b from 0 to 1
Normal  ScalingReplicaSet  3m56s                  deployment-controller  Scaled down replica set hello-py-c7c46d79b from 1 to 0
```

Đọc: lúc 3m56s trước, phiên bản c7c46d79b bị hạ về 0 (lệnh của người thử) và được đưa lên lại 1 trong cùng thời điểm.

## 2. Ai đưa lên lại: faas-netes

managedFields của Deployment (chương trình nào sửa lần cuối):

```
faas-netes      Update
faas-netes      Update          2026-11-01T13:50:38Z
k3s     Update  status  2026-11-01T13:50:53Z
```

Dòng `kubectl ... scale` của người thử đã biến mất vì faas-netes ghi đè lên trường số pod lúc 13:50:38.

Log gateway trong 15 phút, chỉ có 2 request tới hello-py, không có request nào lúc 13:50:38:

```
2026/11/01 13:48:28 Forwarded [GET] to /function/hello-py - [200] - 0.0037s
2026/11/01 13:51:19 Forwarded [GET] to /function/hello-py - [200] - 0.0026s
```

Log faas-netes không có dòng nào về việc đổi số pod (faas-netes làm việc này mà không ghi log).

Nhãn và annotation của Deployment (không có nhãn scale.min nào do nhóm đặt):

```
{"faas_function":"hello-py"}
{"deployment.kubernetes.io/revision":"3","prometheus.io.scrape":"false"}
```

## 3. Phép thử lặp lại

```
$ kubectl -n openfaas-fn scale deployment hello-py --replicas=0
$ kubectl -n openfaas-fn wait --for=delete pod -l faas_function=hello-py --timeout=90s
error: timed out waiting for the condition on pods/hello-py-c7c46d79b-t8cjm
$ kubectl -n openfaas-fn get deployment hello-py
hello-py   1/1     1            1           2d5h
$ sleep 60; kubectl -n openfaas-fn get deployment hello-py
hello-py   1/1     1            1           2d5h
```

Pod không bao giờ biến mất hẳn (pod cũ bị xoá, pod mới t8cjm được tạo ngay), và sau 60 giây không ai gọi vẫn là 1 pod.

## 4. Tăng lên 3 pod không bị chặn

```
$ kubectl -n openfaas-fn scale deployment hello-py --replicas=3
$ sleep 10; kubectl -n openfaas-fn get deployment hello-py
hello-py   3/3     3            3           2d5h
$ sleep 50; kubectl -n openfaas-fn get deployment hello-py
hello-py   3/3     3            3           2d5h
```

## 5. Bộ co giãn có sẵn của CE (bước 2.3)

Tải: k6, 10 VU, 120 giây, GET /function/hello-py, không có HPA hay KEDA.

HTTP
    http_req_duration..............: avg=5.8ms  min=1.46ms med=5.21ms max=66.61ms p(90)=8.9ms  p(95)=10.61ms
      { expected_response:true }...: avg=5.8ms  min=1.46ms med=5.21ms max=66.61ms p(90)=8.9ms  p(95)=10.61ms
    http_req_failed................: 0.00%  0 out of 205112
    http_reqs......................: 205112 1709.177412/s

Số pod theo thời gian (cửa sổ `get deployment -w`):

14:47:59 hello-py   1/1   1     1     2d6h
14:48:04 hello-py   1/1   1     1     2d6h
14:48:09 hello-py   1/1   1     1     2d6h
14:48:14 hello-py   1/1   1     1     2d6h
14:48:19 hello-py   1/1   1     1     2d6h
14:48:24 hello-py   1/1   1     1     2d6h
14:48:30 hello-py   1/2   2     1     2d6h
14:48:35 hello-py   2/2   2     2     2d6h
14:48:40 hello-py   2/2   2     2     2d6h
14:48:45 hello-py   2/2   2     2     2d6h
14:48:50 hello-py   2/2   2     2     2d6h
14:48:55 hello-py   2/2   2     2     2d6h
14:49:01 hello-py   2/2   2     2     2d6h
14:49:06 hello-py   2/2   2     2     2d6h
14:49:11 hello-py   2/3   3     2     2d6h
14:49:16 hello-py   3/3   3     3     2d6h
14:49:21 hello-py   3/3   3     3     2d6h
14:49:27 hello-py   3/3   3     3     2d6h
14:49:32 hello-py   3/3   3     3     2d6h
14:49:37 hello-py   3/3   3     3     2d6h
14:49:42 hello-py   3/3   3     3     2d6h
14:49:47 hello-py   3/3   3     3     2d6h
14:49:52 hello-py   3/4   4     3     2d6h
14:49:58 hello-py   3/4   4     3     2d6h
14:50:03 hello-py   3/4   4     3     2d6h
14:50:08 hello-py   1/1   1     1     2d6h
14:50:13 hello-py   1/1   1     1     2d6h
14:50:18 hello-py   1/1   1     1     2d6h
14:50:23 hello-py   1/1   1     1     2d6h
14:50:28 hello-py   1/1   1     1     2d6h
14:50:33 hello-py   1/1   1     1     2d6h
14:50:38 hello-py   1/1   1     1     2d6h
14:50:43 hello-py   1/1   1     1     2d6h
14:50:48 hello-py   1/1   1     1     2d6h
14:50:54 hello-py   1/1   1     1     2d6h
14:50:59 hello-py   1/1   1     1     2d6h
14:51:04 hello-py   1/1   1     1     2d6h
14:51:09 hello-py   1/1   1     1     2d6h
14:51:14 hello-py   1/1   1     1     2d6h
14:51:19 hello-py   1/1   1     1     2d6h
14:51:24 hello-py   1/1   1     1     2d6h
14:51:29 hello-py   1/1   1     1     2d6h
14:51:34 hello-py   1/1   1     1     2d6h
14:51:39 hello-py   1/1   1     1     2d6h
14:51:44 hello-py   1/1   1     1     2d6h
14:51:50 hello-py   1/1   1     1     2d6h
14:51:55 hello-py   1/1   1     1     2d6h
14:52:00 hello-py   1/1   1     1     2d6h
14:52:05 hello-py   1/1   1     1     2d6h
14:52:10 hello-py   1/1   1     1     2d6h

Kết luận: Số pod có tự tăng.

## 6. KEDA minReplicaCount 0 (bước 2.4)

File: autoscaling/keda/hello-py-scaletozero.yaml. Theo dõi 3 phút không gọi function.

NAME       SCALETARGETKIND      SCALETARGETNAME   MIN   MAX   READY   ACTIVE   FALLBACK   PAUSED   TRIGGERS     AUTHENTICATIONS   AGE
hello-py   apps/v1.Deployment   hello-py          0     5     True    False    False      False    prometheus                     30s

Events sau 3 phút:

15:07:46 hello-py   0/1   1     0     2d6h
15:07:51 hello-py   0/1   1     0     2d6h
15:07:56 hello-py   0/1   1     0     2d6h
15:08:01 hello-py   0/1   1     0     2d6h
15:08:07 hello-py   0/1   1     0     2d6h
15:08:12 hello-py   0/1   1     0     2d6h
15:08:17 hello-py   0/1   1     0     2d6h
15:08:22 hello-py   0/1   1     0     2d6h
15:08:27 hello-py   0/1   1     0     2d6h
15:08:32 hello-py   0/1   1     0     2d6h
15:08:37 hello-py   0/1   1     0     2d6h
15:08:42 hello-py   0/1   1     0     2d6h
15:08:47 hello-py   0/1   1     0     2d6h
15:08:52 hello-py   0/1   1     0     2d6h
15:08:58 hello-py   0/1   1     0     2d6h
15:09:03 hello-py   0/1   1     0     2d6h
15:09:08 hello-py   0/1   1     0     2d6h
15:09:13 hello-py   0/1   1     0     2d6h
15:09:18 hello-py   0/1   1     0     2d6h
15:09:23 hello-py   0/1   1     0     2d6h
15:09:28 hello-py   0/1   1     0     2d6h
15:09:33 hello-py   0/1   1     0     2d6h
15:09:38 hello-py   0/1   1     0     2d6h
15:09:43 hello-py   0/1   1     0     2d6h
15:09:48 hello-py   0/1   1     0     2d6h
15:09:53 hello-py   0/1   1     0     2d6h
15:09:59 hello-py   1/1   1     1     2d6h
15:10:04 hello-py   0/1   1     0     2d6h
15:10:09 hello-py   1/1   1     1     2d6h
15:10:14 hello-py   0/1   1     0     2d6h
15:10:19 hello-py   1/1   1     1     2d6h
15:10:24 hello-py   0/1   1     0     2d6h
15:10:29 hello-py   1/1   1     1     2d6h
15:10:34 hello-py   1/1   1     1     2d6h
15:10:39 hello-py   1/1   1     1     2d6h
15:10:44 hello-py   1/1   1     1     2d6h

Events:
  Type    Reason             Age                   From                   Message
  ----    ------             ----                  ----                   -------
  Normal  ScalingReplicaSet  25m (x4 over 43m)     deployment-controller  Scaled down replica set hello-py-c7c46d79b from 2 to 1
  Normal  ScalingReplicaSet  24m (x5 over 43m)     deployment-controller  Scaled up replica set hello-py-c7c46d79b from 1 to 2
  Normal  ScalingReplicaSet  23m                   deployment-controller  Scaled up replica set hello-py-c7c46d79b from 2 to 3
  Normal  ScalingReplicaSet  5m49s (x31 over 84m)  deployment-controller  Scaled up replica set hello-py-c7c46d79b from 0 to 1
  Normal  ScalingReplicaSet  4m54s (x41 over 82m)  deployment-controller  Scaled down replica set hello-py-c7c46d79b from 1 to 0
tranduc@k3s-master:~/NT533-OpenFaaS-ColdStart-HPA-KEDA$ kubectl -n openfaas-fn get hpa,scaledobject

Kết luận: ScaledObject hoạt động (READY True, ACTIVE False) nhưng KEDA và faas-netes giằng co:
- 15:07:46 - 15:09:53: số pod mong muốn là 1 nhưng không có pod nào sẵn sàng (0/1) suốt khoảng 2 phút,
  pod vừa được faas-netes tạo lại thì bị KEDA hạ về 0.
- 15:09:59 - 15:10:24: nhảy qua lại giữa 1/1 và 0/1.
- 15:10:29 - 15:10:44: ổn định 1/1; chưa rõ vì sao giằng co dừng, thời gian quan sát chưa đủ dài để kết luận.
Các số x31 / x41 trong Events cộng dồn 84 phút, gồm cả các lần scale tay ở các bước khác, không dùng làm số lần giằng co của bước này.
Hệ quả: trên OpenFaaS CE, KEDA với minReplicaCount 0 làm function gần như không phục vụ được; mọi ScaledObject phải đặt minReplicaCount >= 1.
Chưa thử gọi function trong lúc giằng co.
Đã xoá ScaledObject và đưa hello-py về 1 pod sau khi thử.

## 7. Thử cách đo thay thế (bước 2.6)

Đo thời gian từ lúc tăng 1 lên 2 pod tới khi pod thứ hai sẵn sàng (rollout status), 3 lần:

Lan 1: 5343 ms
Lan 2: 3011 ms
Lan 3: 2985 ms

## Kết luận và đề xuất
Nhận xét: lần 1 chậm hơn hẳn (5.3 s), có thể do pod được xếp lên worker chưa có image và phải tải về;
lần 2 và 3 ổn định quanh 3.0 s (image đã có sẵn). Theo quy ước nhóm, bỏ lần đầu.
Thời gian này gồm xếp lịch pod, khởi động container và chờ kiểm tra readiness; chưa gồm thời gian request chờ ở gateway.
Chỉ 3 lần, để kiểm tra phương pháp; số liệu chính thức cần 10-30 lần trên máy đo chuẩn.

1. OpenFaaS CE không cho function ở 0 pod: faas-netes đưa về 1 trong vài giây, không cần request. Đây là giới hạn của bản CE (scale-to-zero thuộc bản trả phí), nay đã được kiểm chứng bằng thực nghiệm.
2. Tăng pod không bị chặn, nên so sánh HPA vs KEDA vẫn làm được trong khoảng từ 1 pod trở lên.
3. Cách đo cold-start trong tài liệu (hạ về 0 rồi gọi request) không dùng được. Đề xuất: đo thời gian một pod mới được tạo tới khi sẵn sàng.
4. TN4 (warm-pool) đổi từ 0 / 1 / 2 thành 1 / 2 / 3 pod chờ sẵn.