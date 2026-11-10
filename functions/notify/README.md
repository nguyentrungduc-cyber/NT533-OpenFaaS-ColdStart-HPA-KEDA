# notify

Mục đích: mô phỏng function xử lý sự kiện (gửi thông báo). Không gửi email/SMS thật,
chỉ ghi log để không phải lưu mật khẩu SMTP trong repo.

Đầu vào: văn bản thuần trong body, hoặc JSON {"channel": "email|sms|...", "message": "..."};
message tối đa 2000 ký tự.

Đầu ra: 202 kèm JSON {"status": "received", "id": "...", "received_at": "..."}.
Đầu vào rỗng, JSON lỗi, thiếu message hoặc quá dài: trả 400.

Mỗi thông báo ghi một dòng log dạng: NOTIFY {"id": ..., "received_at": ..., "channel": ..., "message": ...}
Xem log: faas-cli logs notify   (hoặc: kubectl -n openfaas-fn logs deploy/notify)

Gọi mẫu:
curl -d "Đơn hàng #123 đã giao" http://192.168.243.10:31112/function/notify
curl -H "Content-Type: application/json" -d '{"channel": "email", "message": "Mật khẩu đã đổi"}' http://192.168.243.10:31112/function/notify