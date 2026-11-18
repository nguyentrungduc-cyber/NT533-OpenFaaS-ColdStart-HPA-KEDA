// Buoc 4: do suc chiu C cua 1 pod fibonacci. Chay khi fibonacci dang giu 1 pod, khong gan HPA/KEDA.
//   k6 run -e RATES=10,20,40,80 load-testing/k6-scripts/calibrate.js
// Moi muc chay 1 phut, cach nhau 5 giay. Doc p95 va ty le loi tung muc o phan tong ket:
// C la muc ngay truoc khi p95 tang manh.
import http from 'k6/http';

const GW = __ENV.GATEWAY || 'http://192.168.243.10:31112';
const N = __ENV.N || '20000';
const RATES = (__ENV.RATES || '10,20,40,80').split(',').map(Number);

const scenarios = {};
const thresholds = {};
RATES.forEach((r, i) => {
  const name = `rps${r}`;
  scenarios[name] = {
    executor: 'constant-arrival-rate',
    rate: r, timeUnit: '1s', duration: '1m',
    preAllocatedVUs: 50, maxVUs: 400,
    startTime: `${i * 65}s`,
    tags: { level: String(r) },
  };
  // nguong gia, chi de k6 in rieng p95 va ty le loi cho tung muc
  thresholds[`http_req_duration{level:${r}}`] = ['p(95)<1000000'];
  thresholds[`http_req_failed{level:${r}}`] = ['rate<=1'];
});

export const options = { scenarios, thresholds };

export default function () {
  http.post(`${GW}/function/fibonacci`, N);
}
