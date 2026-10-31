import json
import uuid
from datetime import datetime, timezone

MAX_CHARS = 2000


def handle(event, context):
    raw = event.body.decode("utf-8", errors="replace").strip() if event.body else ""
    if not raw:
        return {"statusCode": 400, "body": "can noi dung thong bao"}

    channel, message = "default", raw
    if raw.startswith("{"):
        try:
            data = json.loads(raw)
            channel = str(data.get("channel", "default"))
            message = str(data.get("message", ""))
        except (ValueError, AttributeError):
            return {"statusCode": 400, "body": "JSON khong hop le"}
    if not message:
        return {"statusCode": 400, "body": "thieu truong message"}
    if len(message) > MAX_CHARS:
        return {"statusCode": 400, "body": f"thong bao qua dai (toi da {MAX_CHARS} ky tu)"}

    record = {
        "id": uuid.uuid4().hex[:12],
        "received_at": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
        "channel": channel,
        "message": message,
    }
    print("NOTIFY " + json.dumps(record, ensure_ascii=False), flush=True)

    return {
        "statusCode": 202,
        "body": json.dumps({"status": "received", "id": record["id"], "received_at": record["received_at"]}),
        "headers": {"Content-Type": "application/json"},
    }