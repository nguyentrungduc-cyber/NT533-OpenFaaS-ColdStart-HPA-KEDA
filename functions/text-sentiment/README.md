# text-sentiment

Mục đích: function nhẹ (dưới 1 ms mỗi câu ngắn) để đo throughput dưới tải cao.

Đầu vào: văn bản thuần trong body, hoặc JSON {"text": "..."}; tối đa 10000 ký tự.
Hỗ trợ tiếng Việt và tiếng Anh, có xử lý phủ định ("không tệ", "not good").

Đầu ra: JSON {"label": "positive|negative|neutral", "score": <số nguyên>, "matched": [các cụm từ khớp]}
Đầu vào rỗng, JSON lỗi hoặc quá dài: trả 400.

Phương pháp: từ điển tự viết, không dùng thư viện học máy để image nhỏ và khởi động nhanh.

Gọi mẫu:
curl -d "Sản phẩm tuyệt vời, giao hàng nhanh" http://192.168.243.10:31112/function/text-sentiment
curl -H "Content-Type: application/json" -d '{"text": "This is not good"}' http://192.168.243.10:31112/function/text-sentiment