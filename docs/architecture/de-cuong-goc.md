# Đề cương đồ án — NT533

**Nghiên cứu và đánh giá các chiến lược tối ưu Cold-Start, so sánh hiệu
năng Autoscaling (HPA vs KEDA) trên hệ thống serverless tự quản lý
(OpenFaaS) triển khai trên Kubernetes multi-node**

*(OpenFaaS + Kubernetes + KEDA + Prometheus/Grafana)*

Số lượng thành viên: 4
Thời gian thực hiện: 1 học kỳ (~15 tuần)

## 1. Tổng quan đề tài

Đề tài xây dựng một nền tảng Function-as-a-Service (FaaS) tự triển khai
(self-hosted serverless) chạy trên cụm Kubernetes nhiều node, kèm hệ
thống giám sát thời gian thực. Khác với việc chỉ dừng ở mức triển khai
và co giãn cơ bản, đồ án lấy hai bài toán nghiên cứu làm trọng tâm:
(1) tối ưu độ trễ khởi động lạnh (cold-start) — đặc trưng cốt lõi phân
biệt serverless thật sự với microservices thông thường, và (2) so sánh
định lượng hai chiến lược autoscaling phổ biến là HPA (dựa trên
CPU/RAM) và KEDA (dựa trên sự kiện/RPS).

Đề tài được lựa chọn thay thế các nền tảng IaaS nặng (OpenStack,
CloudStack, Eucalyptus, OpenNebula) vì lý do khả thi: nhóm chỉ có
laptop cá nhân, không có cụm máy chủ vật lý. OpenFaaS trên Kubernetes
(dùng k3s) cho phép mô phỏng đúng kiến trúc multi-node (control-plane +
nhiều worker node) bằng máy ảo nhẹ, đồng thời vẫn bao trọn các nội dung
cốt lõi của môn học: container hóa, điều phối phân tán (orchestration),
và autoscaling.

### 1.1. Lý do lựa chọn

- Nhẹ, khả thi trên laptop cá nhân: mỗi node chỉ cần 2GB RAM, tổng cụm
  3-4 node chạy tốt trên VirtualBox/VMware.
- Tài liệu và cộng đồng OpenFaaS/KEDA lớn, dễ triển khai phần lõi trong
  1-2 tuần, dành nhiều thời gian cho phần thực nghiệm & phân tích.
- Gộp được nhiều nội dung của đề cương gốc: Cloud/Container (mục III) +
  Autoscaling (mục VI) + Optimization (mục VII) qua bài toán tối ưu
  cold-start.
- Có tính nghiên cứu và tính mới: thay vì chỉ "triển khai thành công"
  như các đề tài FaaS/Kubernetes cùng lớp, đồ án có trục thực nghiệm so
  sánh định lượng riêng (cold-start, HPA vs KEDA), tránh trùng lặp với
  các nhóm khác cùng chủ đề nền tảng OpenFaaS/Kubernetes.

### 1.2. Mục tiêu đồ án

- Triển khai thành công cụm Kubernetes multi-node (tối thiểu 1
  control-plane + 3 worker node) trên máy ảo.
- Cài đặt và cấu hình OpenFaaS Gateway trên cụm, viết tối thiểu 5
  serverless functions minh họa (xử lý ảnh, gửi email, xử lý dữ liệu,
  v.v.), cấu hình scale-to-zero cho các function.
- Thử nghiệm và so sánh các chiến lược giảm độ trễ cold-start:
  warm-pool, tối ưu container image, điều chỉnh readiness/liveness
  probe.
- Triển khai và so sánh hai chiến lược autoscaling: HPA (CPU/RAM) và
  KEDA (event-driven/RPS) trên cùng một kịch bản tải.
- Xây dựng bộ công cụ load-testing (k6/hey) để tạo tải và đo lường thời
  gian phản hồi, tốc độ scale, độ trễ cold-start.
- Triển khai hệ thống giám sát (Prometheus + Grafana) hiển thị dashboard
  thời gian thực.
- Viết báo cáo phân tích, đưa ra khuyến nghị chiến lược cold-start
  mitigation và autoscaling phù hợp cho từng loại workload.

## 2. Kiến trúc hệ thống

### 2.1. Sơ đồ tổng thể

Cụm gồm 1 node control-plane (quản lý cluster, scheduler, API server)
và 3 node worker (chạy các pod function thực tế). Toàn bộ được triển
khai trên 4 máy ảo VirtualBox/VMware, kết nối qua mạng nội bộ
(host-only hoặc bridged network).

| Thành phần | Vai trò | Công nghệ |
|---|---|---|
| Control-plane node | Quản lý cluster, API server, scheduler, etcd | k3s / kubeadm |
| Worker node (x3) | Chạy pod của các function | k3s agent + containerd |
| OpenFaaS Gateway | Nhận request, định tuyến đến function tương ứng, quản lý scale-to-zero | OpenFaaS Core |
| Function Watchdog | Sidecar chuyển HTTP request thành lời gọi hàm | of-watchdog |
| Autoscaler (HPA) | Co giãn pod theo CPU/RAM | Kubernetes HPA + metrics-server |
| Autoscaler (KEDA) | Co giãn pod theo sự kiện/RPS/queue-length | KEDA |
| Load generator | Tạo tải thử nghiệm, đo độ trễ, throughput, cold-start latency | k6 hoặc hey |
| Monitoring stack | Thu thập & trực quan hóa metrics | Prometheus + Grafana |

### 2.2. Luồng xử lý request

- Client gửi HTTP request đến OpenFaaS Gateway.
- Nếu function đang ở trạng thái 0 pod (scale-to-zero), Gateway kích
  hoạt cold-start: tạo pod mới rồi mới forward request — đây là điểm
  đo độ trễ chính trong thực nghiệm cold-start.
- Nếu tải tăng cao, HPA hoặc KEDA (tùy kịch bản thử nghiệm) tự động tạo
  thêm pod mới trên các worker node còn tài nguyên.
- Kết quả trả về client; đồng thời Prometheus liên tục scrape metrics
  (CPU, số request, độ trễ, thời gian pod sẵn sàng) để hiển thị lên
  Grafana dashboard.

## 3. Công nghệ và công cụ sử dụng

| Lớp | Công cụ | Ghi chú |
|---|---|---|
| Hạ tầng ảo hóa | VirtualBox/VMware + Vagrant (khuyến nghị) | Vagrant giúp dựng lại cụm tự động, dễ tái tạo demo |
| Hệ điều hành node | Ubuntu Server 22.04 LTS | Nhẹ, ổn định, tài liệu nhiều |
| Container runtime | containerd (đi kèm k3s) | Không cần cài Docker riêng |
| Orchestration | k3s (Kubernetes nhẹ) | Thay thế kubeadm để giảm tải RAM |
| Serverless platform | OpenFaaS (faasd hoặc OpenFaaS trên K8s) | https://github.com/openfaas/faas — hỗ trợ scale-to-zero |
| Autoscaling | Kubernetes HPA + metrics-server, KEDA | So sánh 2 chiến lược trên cùng kịch bản tải |
| Cold-start optimization | Warm-pool, distroless image, tinh chỉnh probe | Trọng tâm thực nghiệm của đồ án |
| Load testing | k6 hoặc hey | Đo độ trễ, throughput, cold-start latency dạng biểu đồ |
| Monitoring | Prometheus + Grafana | Dashboard CPU, RAM, số pod, request/s, latency |
| CI/CD (tùy chọn) | GitHub Actions | Tự động build & deploy function khi push code |

## 4. Phân chia công việc (4 thành viên)

| Thành viên | Vai trò | Nhiệm vụ chính |
|---|---|---|
| Người 1 | Hạ tầng & Cluster | Dựng 4 VM, cài đặt k3s multi-node, cấu hình networking, Ingress controller |
| Người 2 | Serverless Platform & Cold-start | Cài đặt OpenFaaS, viết 5+ functions demo, cấu hình scale-to-zero, thử nghiệm các chiến lược tối ưu cold-start (warm-pool, image tối ưu, probe) |
| Người 3 | Autoscaling & Testing | Cấu hình & so sánh HPA vs KEDA, viết kịch bản load test bằng k6/hey, thu thập số liệu hiệu năng và cold-start latency |
| Người 4 | Monitoring & Báo cáo | Triển khai Prometheus/Grafana, xây dashboard, tổng hợp số liệu, viết báo cáo & slide bảo vệ |

*Lưu ý: các vai trò có phụ thuộc lẫn nhau (VD: Người 3 cần cluster từ
Người 1 và function từ Người 2 để test), nên timeline cần đồng bộ theo
tuần như bảng mục 5.*

## 5. Kế hoạch thực hiện theo tuần (15 tuần)

Xem bảng chi tiết tại [`../weekly-reports/README.md`](../weekly-reports/README.md).

## 6. Kết quả mong đợi

- Cụm Kubernetes multi-node hoạt động ổn định, có thể demo trực tiếp
  trên laptop nhóm.
- Hệ thống OpenFaaS với tối thiểu 5 function chạy thực tế, hỗ trợ
  scale-to-zero, có thể gọi qua HTTP/CLI.
- Biểu đồ/số liệu so sánh độ trễ cold-start giữa các chiến lược tối ưu
  (warm-pool, image nhẹ, mặc định).
- Biểu đồ/số liệu so sánh hiệu năng HPA vs KEDA: thời gian phản hồi,
  tốc độ scale, mức sử dụng tài nguyên.
- Dashboard Grafana trực quan hiển thị trạng thái hệ thống theo thời
  gian thực.
- Báo cáo phân tích và khuyến nghị: chiến lược cold-start mitigation và
  autoscaling phù hợp theo từng loại workload.

## 7. Rủi ro và phương án dự phòng

| Rủi ro | Mức độ | Phương án xử lý |
|---|---|---|
| Laptop không đủ RAM chạy 4 VM cùng lúc | Cao | Dùng k3s (nhẹ hơn kubeadm), giảm còn 3 node (1 control-plane + 2 worker), hoặc dùng kind thay VM thật |
| Cấu hình network giữa các VM lỗi (node không join được cluster) | Trung bình | Dùng Vagrant script để tái tạo cluster tự động, tránh lỗi thao tác tay |
| KEDA cấu hình phức tạp hơn dự kiến, không kịp so sánh với HPA | Trung bình | Ưu tiên hoàn thiện HPA + cold-start trước; KEDA làm sau, nếu thiếu thời gian thì báo cáo dựa trên cấu hình mặc định |
| Thiếu thời gian làm phần monitoring | Thấp | Ưu tiên Prometheus + Grafana cơ bản trước, bỏ qua alerting nếu thiếu thời gian |

## 8. Tài liệu tham khảo

- OpenFaaS — https://github.com/openfaas/faas
- k3s — Lightweight Kubernetes — https://k3s.io
- KEDA — Kubernetes Event-Driven Autoscaling — https://keda.sh
- Kubernetes Horizontal Pod Autoscaler — https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- Prometheus — https://prometheus.io
- Grafana — https://grafana.com
- k6 Load Testing — https://k6.io
- server-world.info — hướng dẫn triển khai tham khảo từ đề cương môn học
