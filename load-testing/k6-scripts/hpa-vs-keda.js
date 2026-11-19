// So sanh HPA vs KEDA tren fibonacci. Chon kich ban bang PROFILE, muc tai tinh theo C.
//   k6 run -e PROFILE=spike -e C=40 --summary-trend-stats="avg,min,med,max,p(90),p(95),p(99)" \
//     --summary-export=results/hpa-vs-keda/hpa_spike_run1.summary.json k6-scripts/hpa-vs-keda.js
// Dung arrival-rate (toc do gui co dinh) thay vi VU co dinh: khi he thong cham, k6 van gui
// du request, khong bi "coordinated omission" lam giam tai that dung luc can do.
// Quy trinh do mot lan: ../README.md. C = suc chiu cua 1 pod (40 req/s, xem ../../autoscaling/README.md).
// Muc nen cua spike/step la B = 0.5C (20 req/s), duoi nguong scale (~24 req/s) de bat dau tu dung 1 pod;
// docx dung C (40 req/s) nhung muc do da vuot nguong nen he thong len 2 pod truoc khi tai tang.
import http from 'k6/http';

const GW = __ENV.GATEWAY || 'http://192.168.243.10:31112';
const FN = __ENV.FN || 'fibonacci';
const N = __ENV.N || '20000';
const C = Number(__ENV.C || 40);
const B = C / 2;

const profiles = {
  steady: [{ target: 3 * C, duration: '30s' }, { target: 3 * C, duration: '4m' }],
  ramp:   [{ target: 4 * C, duration: '4m' }, { target: 4 * C, duration: '1m' }],
  spike:  [{ target: B, duration: '1m' }, { target: 4 * C, duration: '10s' },
           { target: 4 * C, duration: '2m' }, { target: B, duration: '10s' }, { target: B, duration: '1m' }],
  step:   [{ target: B, duration: '1m' }, { target: 2 * C, duration: '5s' }, { target: 2 * C, duration: '1m' },
           { target: 3 * C, duration: '5s' }, { target: 3 * C, duration: '1m' }, { target: 4 * C, duration: '5s' },
           { target: 4 * C, duration: '1m' }],
  burst:  [{ target: 4 * C, duration: '5s' }, { target: 4 * C, duration: '30s' }, { target: 0, duration: '5s' },
           { target: 0, duration: '1m' }, { target: 4 * C, duration: '5s' }, { target: 4 * C, duration: '30s' }],
};

const profile = __ENV.PROFILE || 'steady';
if (!profiles[profile]) throw new Error(`PROFILE khong hop le: ${profile} (chon: ${Object.keys(profiles).join(', ')})`);

export const options = {
  scenarios: {
    load: {
      executor: 'ramping-arrival-rate',
      startRate: 1, timeUnit: '1s',
      preAllocatedVUs: 200, maxVUs: 600, // VU co san tu dau: khoi tao VU luc dang chay lam k6 bo request (dropped_iterations)
      stages: profiles[profile],
    },
  },
};

export default function () {
  http.post(`${GW}/function/${FN}`, N, { timeout: '10s' });
}
