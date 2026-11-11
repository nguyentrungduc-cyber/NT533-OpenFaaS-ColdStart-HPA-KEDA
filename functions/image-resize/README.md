# image-resize

Mục đích: function có image lớn (kèm thư viện Pillow) và tốn CPU thật, dùng cho thí nghiệm
kích thước image (TN2) và pre-pull (TN3).

Đầu vào: JSON

```json
{"image": "<base64 hoặc data:image/...;base64,...>", "width": 200, "height": 150, "format": "PNG|JPEG|WEBP"}
```

- Cần ít nhất `width` hoặc `height`; chỉ cho một cạnh thì giữ tỉ lệ
- Đọc được ảnh PNG, JPEG, WEBP, GIF, BMP
- `format` không bắt buộc: mặc định giữ định dạng gốc nếu là PNG/JPEG/WEBP (nhận cả `JPG`).
  Ảnh gốc GIF hoặc BMP thì **phải** truyền `format`, nếu không sẽ trả 400
- Giới hạn: ảnh gốc 5 MB và tối đa 25 triệu điểm ảnh, cạnh đầu ra 1-4000 px

Đầu ra: JSON `{"original": {"width", "height"}, "width", "height", "format", "bytes", "elapsed_ms", "image": "<base64>"}`

Đầu vào sai: trả 400.

Gọi mẫu (anh.jpg có sẵn trên máy):

```bash
printf '{"image":"%s","width":200}' "$(base64 -w0 anh.jpg)" > req.json
curl -d @req.json http://192.168.243.10:31112/function/image-resize
```
