# data-transform

Mục đích: function Node.js (template node24) để so sánh cold-start Python vs Node.js.

Đầu vào: JSON, BẮT BUỘC gửi kèm header Content-Type: application/json
{
  "records": [{"id": 1, "cust": "An", "amt": 120, "st": "paid"}, ...],   (tối đa 10000, body tối đa 1 MB)
  "rename": {"cust": "customer", "amt": "amount", "st": "status"},      (không bắt buộc)
  "filter": {"field": "status", "equals": "paid"},                      (không bắt buộc; equals | gt | lt)
  "sum": "amount"                                                       (không bắt buộc)
}
Thứ tự xử lý: đổi tên -> lọc -> tính tổng; filter và sum dùng tên trường SAU khi đổi.

Đầu ra: JSON {"count_in", "count_out", "sum": {"field", "total"} | null, "elapsed_ms", "records": [...]}
Đầu vào sai hoặc thiếu header JSON: trả 400.

Gọi mẫu:
curl -H "Content-Type: application/json" \
  -d '{"records":[{"id":1,"amt":120,"st":"paid"},{"id":2,"amt":80,"st":"pending"}],"filter":{"field":"st","equals":"paid"},"sum":"amt"}' \
  http://192.168.243.10:31112/function/data-transform