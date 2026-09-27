"""
handler.py — hello-world function
Function tối thiểu để test nhanh: OpenFaaS Gateway hoạt động chưa,
scale-to-zero có hoạt động chưa, dùng làm baseline đo cold-start latency
(vì logic đơn giản nhất, không có dependency nặng làm nhiễu số liệu).

TODO (Người 2): điền logic thật nếu cần, hoặc giữ nguyên làm baseline.
"""

def handle(event, context):
    return {
        "statusCode": 200,
        "body": "Hello from OpenFaaS! Function is warm and responding."
    }
