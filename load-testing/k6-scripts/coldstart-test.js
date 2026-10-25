// coldstart-test.js — Đo cold-start latency của OpenFaaS function
//
// Nguyên lý:
//   1. Bảo đảm function đang ở trạng thái scale-to-zero (0 pod)
//   2. Gọi function lần ĐẦU TIÊN → đây là cold-start (tạo pod từ đầu)
//   3. Gọi thêm N lần tiếp theo → warm call (pod đã tồn tại)
//   4. So sánh duration: lần 1 (cold) vs lần 2-N (warm)
//
// Cách chạy:
//   # Dùng IP mặc định (192.168.243.10):
//   k6 run coldstart-test.js
//
//   # Đặt gateway tùy chỉnh (VD qua Tailscale):
//   k6 run -e GATEWAY=http://100.88.160.40:31112 coldstart-test.js
//
//   # Lưu kết quả ra file:
//   k6 run coldstart-test.js --out json=../results/coldstart/run-01.json
//
// Trước khi chạy — bảo đảm function đã scale về 0:
//   kubectl scale deployment hello-world -n openfaas-fn --replicas=0
//   kubectl get pods -n openfaas-fn -w   # chờ pod Terminating xong

import http from 'k6/http';
import { sleep, check } from 'k6';

// Đọc GATEWAY từ biến môi trường, fallback về IP thực tế của cluster
const GATEWAY_BASE = __ENV.GATEWAY || 'http://192.168.243.10:31112';
const FUNCTION_URL = `${GATEWAY_BASE}/function/hello-world`;

export const options = {
  scenarios: {
    cold_start_measurement: {
      executor: 'per-vu-iterations',
      vus: 1,          // 1 VU duy nhất để đảm bảo tuần tự
      iterations: 10,  // lần 1 = cold, lần 2-10 = warm
    },
  },
  // Không set thresholds ở đây — mình phân tích thủ công từ output
};

// Biến đếm iteration toàn cục
let iterationCount = 0;

export default function () {
  iterationCount++;
  const callType = iterationCount === 1 ? 'COLD' : 'WARM';

  const start = Date.now();
  const res = http.get(FUNCTION_URL, {
    timeout: '60s',  // cold-start có thể mất đến 30-60s lần đầu
  });
  const duration = Date.now() - start;

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  console.log(
    `[${callType}] iter=${iterationCount} ` +
    `status=${res.status} ` +
    `duration=${res.timings.duration.toFixed(0)}ms ` +
    `ttfb=${res.timings.waiting.toFixed(0)}ms`
  );

  // Không sleep giữa các lần gọi để lần 2 trở đi đúng là warm call
  // (nếu sleep quá lâu, pod có thể scale về 0 giữa chừng)
  if (iterationCount >= 2) {
    sleep(0.5);
  }
}

export function handleSummary(data) {
  // In summary có thêm dòng ghi chú để phân biệt cold vs warm
  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
