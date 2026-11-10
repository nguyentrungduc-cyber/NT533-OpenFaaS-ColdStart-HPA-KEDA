import json
import re
import unicodedata

MAX_CHARS = 10000

POSITIVE = {
    "tốt", "tuyệt", "tuyệt vời", "xuất sắc", "đẹp", "thích", "yêu", "vui",
    "hài lòng", "nhanh", "ổn", "tiện", "hữu ích", "dễ dùng", "ngon", "ấn tượng",
    "good", "great", "excellent", "amazing", "love", "like", "happy", "nice",
    "fast", "useful", "awesome", "perfect", "satisfied",
}
NEGATIVE = {
    "tệ", "dở", "xấu", "chậm", "lỗi", "ghét", "buồn", "thất vọng", "khó dùng",
    "kém", "tồi", "chán", "phức tạp", "hỏng", "đắt",
    "bad", "terrible", "awful", "slow", "hate", "sad", "broken", "bug",
    "poor", "worst", "disappointed", "boring", "expensive",
}
NEGATORS = {"không", "chẳng", "chả", "chưa", "not", "never", "no", "don't", "isn't"}

LEXICON = sorted(
    [(w, 1) for w in POSITIVE] + [(w, -1) for w in NEGATIVE],
    key=lambda item: -len(item[0]),
)


def tokenize(text):
    text = unicodedata.normalize("NFC", text.lower())
    return re.findall(r"[\w']+", text)


def analyze(text):
    tokens = tokenize(text)
    score, matched, i = 0, [], 0
    while i < len(tokens):
        for phrase, polarity in LEXICON:
            words = phrase.split()
            if tokens[i:i + len(words)] == words:
                negated = i > 0 and tokens[i - 1] in NEGATORS
                value = -polarity if negated else polarity
                score += value
                matched.append(f"{tokens[i - 1]} {phrase}" if negated else phrase)
                i += len(words)
                break
        else:
            i += 1
    label = "positive" if score > 0 else "negative" if score < 0 else "neutral"
    return {"label": label, "score": score, "matched": matched}


def handle(event, context):
    raw = event.body.decode("utf-8", errors="replace").strip() if event.body else ""
    text = raw
    if raw.startswith("{"):
        try:
            text = str(json.loads(raw).get("text", ""))
        except (ValueError, AttributeError):
            return {"statusCode": 400, "body": "JSON khong hop le"}
    if not text:
        return {"statusCode": 400, "body": "can noi dung van ban"}
    if len(text) > MAX_CHARS:
        return {"statusCode": 400, "body": f"van ban qua dai (toi da {MAX_CHARS} ky tu)"}

    result = analyze(text)
    return {
        "statusCode": 200,
        "body": json.dumps(result, ensure_ascii=False),
        "headers": {"Content-Type": "application/json; charset=utf-8"},
    }