import json
import time

MAX_N = 100000


def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a


def handle(event, context):
    raw = event.body.decode().strip() if event.body else ""
    try:
        n = int(raw or "30")
    except ValueError:
        return {"statusCode": 400, "body": "n phai la so nguyen"}
    if n < 0:
        return {"statusCode": 400, "body": "n phai >= 0"}
    n = min(n, MAX_N)

    start = time.perf_counter()
    value = fib(n)
    elapsed_ms = (time.perf_counter() - start) * 1000

    return {
        "statusCode": 200,
        "body": json.dumps({"n": n, "bits": value.bit_length(), "elapsed_ms": round(elapsed_ms, 2)}),
        "headers": {"Content-Type": "application/json"},
    }