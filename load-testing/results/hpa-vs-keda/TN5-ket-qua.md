# TN5 - Kết quả: HPA vs KEDA dưới tải Spike

## Cấu hình thí nghiệm

- **Load profile:** spike (`PROFILE=spike`, `C=40`)
- **Lưu lượng:** baseline 20 req/s → đỉnh 160 req/s (10s ramp) → 2m tại đỉnh → về baseline
- **Tổng thời gian:** ~4m20s (5 stages)
- **VUs tối đa:** 600

### HPA
- CPU target: 50% (requests=350m)
- minReplicas=1, maxReplicas=5
- stabilizationWindowSeconds=300

### KEDA
- Trigger: Prometheus `rate(gateway_function_invocation_total{function_name="fibonacci.openfaas-fn"}[30s])`
- threshold=24 req/s, pollingInterval=15s
- minReplicaCount=1, maxReplicaCount=5

---

## Kết quả đo

| Lượt | p50 | p95 | Error rate | Dropped iterations | Iterations |
|------|-----|-----|------------|-------------------|------------|
| HPA run1 | 1.11s | 10s | 34.85% | 1909 | 18767 |
| HPA run2 | 1.11s | 10s | 40.34% | 3658 | 18767 |
| HPA run3 | 230ms | 10s | 40.02% | 4062 | 18767 |
| **HPA trung bình** | | **10s** | **38.40%** | **3210** | |
| KEDA run1 | 230ms | 10s | 38.77% | 2708 | 20121 |
| KEDA run2 | 15ms | 10s | 37.10% | 1829 | 21000 |
| KEDA run3 | 13ms | 10s | 36.00% | 1463 | 21366 |
| **KEDA trung bình** | | **10s** | **37.29%** | **2000** | |

> p95 = 10s toàn bộ: đây là timeout của k6 (`http_req_timeout=10s`), phản ánh request bị drop hoàn toàn khi autoscaler không kịp scale.

---

## Nhận xét

- **Cả HPA và KEDA đều không scale kịp** spike 160 req/s từ 1 pod: p95=10s (timeout) ở tất cả 6 lượt.
- **KEDA nhỉnh hơn HPA** về error rate (~37% vs ~38%) và dropped iterations (~2000 vs ~3210), nhờ metric Prometheus phản hồi nhanh hơn CPU metric.
- **HPA run2/3 tệ hơn run1** do `stabilizationWindowSeconds=300` — HPA chưa scale down hết trước khi run tiếp theo bắt đầu, gây backpressure.
- **Nguyên nhân chính:** cả hai autoscaler đều cần ít nhất 1 chu kỳ scrape (15–30s) để detect và scale; spike 10s quá ngắn để phản ứng kịp.
