// autoscaling-test.js — Tạo tải tăng dần để so sánh tốc độ scale HPA vs KEDA
//
// Nguyên lý:
//   Dùng ramping VUs để mô phỏng tải tăng dần, quan sát:
//     - Thời điểm pod mới xuất hiện (scale-up latency)
//     - Số pod tối đa được tạo ra
//     - Thời gian latency trung bình trong lúc scale đang diễn ra
//     - Thời điểm scale-down khi tải giảm
//
// Cách chạy:
//   # Chạy với IP mặc định:
//   k6 run autoscaling-test.js
//
//   # Đặt gateway tùy chỉnh:
//   k6 run -e GATEWAY=http://100.88.160.40:31112 autoscaling-test.js
//
//   # Lưu kết quả:
//   k6 run autoscaling-test.js \
//     --out json=../results/hpa-vs-keda/hpa-run-01.json
//   k6 run autoscaling-test.js \
//     --out json=../results/hpa-vs-keda/keda-run-01.json
//
// Quy trình so sánh HPA vs KEDA:
//   1. kubectl delete scaledobject hello-world-keda -n openfaas-fn  # tắt KEDA
//      kubectl apply -f ../../autoscaling/hpa/hpa-config.yaml       # bật HPA
//      k6 run autoscaling-test.js --out json=../results/hpa-vs-keda/hpa-run-01.json
//
//   2. kubectl delete hpa hello-world-hpa -n openfaas-fn            # tắt HPA
//      kubectl apply -f ../../autoscaling/keda/keda-scaledobject.yaml # bật KEDA
//      k6 run autoscaling-test.js --out json=../results/hpa-vs-keda/keda-run-01.json
//
//   3. So sánh hai file JSON: thời gian response, tốc độ scale
//
// Song song với k6, chạy lệnh này để ghi lại timestamp pod xuất hiện:
//   watch -n 2 "kubectl get pods -n openfaas-fn | tee -a pod-events.log"

import http from 'k6/http';
import { sleep, check } from 'k6';

const GATEWAY_BASE = __ENV.GATEWAY || 'http://192.168.243.10:31112';
const FUNCTION_URL = `${GATEWAY_BASE}/function/hello-world`;

export const options = {
  stages: [
    { duration: '30s', target: 5   },  // khởi động nhẹ
    { duration: '60s', target: 30  },  // tăng dần — trigger scale
    { duration: '60s', target: 80  },  // tải cao — quan sát max pod count
    { duration: '30s', target: 5   },  // giảm về thấp — quan sát scale-down
    { duration: '30s', target: 0   },  // dừng hẳn — quan sát scale-to-zero (KEDA)
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'],  // 95% request phải dưới 5s
    http_req_failed:   ['rate<0.05'],   // tỉ lệ lỗi dưới 5%
  },
};

export default function () {
  const res = http.get(FUNCTION_URL, {
    timeout: '30s',
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  // Sleep ngắn để tránh hammer quá mức một VU
  sleep(0.1);
}
