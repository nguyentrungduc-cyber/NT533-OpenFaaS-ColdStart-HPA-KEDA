// coldstart-test.js — Đo độ trễ cold-start
// Ý tưởng: gọi function sau khi nó đã scale về 0 (chờ đủ lâu), đo thời
// gian phản hồi lần gọi ĐẦU TIÊN (cold) so với các lần gọi SAU (warm).
//
// TODO (Người 3): điền URL Gateway thật sau khi OpenFaaS đã deploy

import http from 'k6/http';
import { sleep } from 'k6';

const GATEWAY_URL = 'http://<GATEWAY_IP>:8080/function/hello-world'; // TODO

export const options = {
  scenarios: {
    cold_start_measurement: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 5, // gọi 5 lần: lần 1 = cold, lần 2-5 = warm để so sánh
    },
  },
};

export default function () {
  const res = http.get(GATEWAY_URL);
  console.log(`Status: ${res.status}, Duration: ${res.timings.duration}ms`);

  // TODO: ghi lại res.timings.duration vào file kết quả, đánh dấu lần
  // đầu tiên (cold) riêng biệt với các lần sau (warm)

  sleep(1);
}
