// autoscaling-test.js — Tạo tải tăng dần để đo tốc độ scale của HPA/KEDA
// Ý tưởng: dùng ramping VUs để mô phỏng tải tăng dần, đo thời điểm pod
// mới xuất hiện (qua kubectl get pods song song, hoặc qua Prometheus).
//
// TODO (Người 3): điền URL Gateway thật, tinh chỉnh stages theo kịch bản

import http from 'k6/http';

const GATEWAY_URL = 'http://<GATEWAY_IP>:8080/function/hello-world'; // TODO

export const options = {
  stages: [
    { duration: '30s', target: 5 },   // tải nhẹ ban đầu
    { duration: '1m', target: 50 },   // tăng dần để trigger scale
    { duration: '1m', target: 100 },  // tải cao để so sánh tốc độ scale HPA vs KEDA
    { duration: '30s', target: 0 },   // giảm về 0, quan sát scale-down
  ],
};

export default function () {
  http.get(GATEWAY_URL);
}

// TODO: chạy song song script này khi target là HPA và khi target là
// KEDA (đổi autoscaler đang active), so sánh log/kubectl get hpa,scaledobject
// -w để ghi lại timestamp pod mới xuất hiện.
