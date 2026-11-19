#!/usr/bin/env python3
"""Phan tich ket qua HPA vs KEDA (va ve boxplot cold-start).

Du lieu vao, trong load-testing/results/hpa-vs-keda/, moi lan do co 3 file cung ten
<tool>_<profile>_run<N>, vi du hpa_spike_run1:
  .csv           do record-replicas.sh ghi (ts_ms,ready,desired)
  .start         moc bat dau tai (date +%s%3N, ghi ngay truoc khi chay k6)
  .summary.json  do k6 --summary-export (can --summary-trend-stats co p(99))
  .cpu.csv       (tuy chon) do record-cpu.sh ghi (ts_ms,cpu_pct_avg) -> cot cpu_pct_avg
Moc "tai bat dau tang" va "het tai" cua tung kich ban nam o bang MARKS ben duoi.

Dung:
  python analyze.py hpa-vs-keda [thu_muc_ket_qua]        -> bang so lieu + hinh trong analysis/out/
  python analyze.py coldstart file1.csv [file2.csv ...]  -> boxplot cold-start
"""
import glob
import json
import os
import re
import sys

import matplotlib
import pandas as pd

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
COLORS = {"hpa": "tab:blue", "keda": "tab:orange"}


# Moc thoi gian (giay tu luc bat dau tai) theo hpa-vs-keda.js: jump = luc tai bat dau vuot muc nen,
# load_off = luc tai ha xuong muc nen lan cuoi (tu day moi tinh thoi gian giam pod).
# Phai sua cung luc voi stages trong k6-scripts/hpa-vs-keda.js.
MARKS = {
    "steady": {"jump": 0, "load_off": 270},   # 30s len + 4m giu
    "ramp":   {"jump": 0, "load_off": 300},   # 4m len + 1m giu
    "spike":  {"jump": 60, "load_off": 200},  # nen 1m, nhay 10s, giu 2m, ha 10s (con 1m nen)
    "step":   {"jump": 60, "load_off": 255},  # nen 1m, bac 2C, 3C, 4C; het la het tai
    "burst":  {"jump": 0, "load_off": 135},   # dot 1 ngay tu dau; load_off = het dot 2
}


def metric(summary, name, key, default=None):
    m = summary["metrics"].get(name)
    if m is None:  # k6 bo han metric neu chua tung xay ra (vd dropped_iterations = 0)
        if default is None:
            raise KeyError(name)
        return default
    return m.get("values", m)[key]  # k6 ban cu co "values", ban moi khong


def load_run(base):
    """Doc file .csv va .start, them cot t (giay tinh tu luc bat dau tai)."""
    df = pd.read_csv(base + ".csv")
    df["ready"] = pd.to_numeric(df["ready"], errors="coerce").fillna(0)
    df["desired"] = pd.to_numeric(df["desired"], errors="coerce")
    t0 = int(open(base + ".start").read().strip())
    df["t"] = (df["ts_ms"] - t0) / 1000.0
    return df


def cpu_mean(base, window):
    """CPU trung binh cua cum (%) trong [0, window] tu file <base>.cpu.csv do record-cpu.sh ghi; NaN neu khong co."""
    path = base + ".cpu.csv"
    if not os.path.exists(path):
        return float("nan")
    c = pd.read_csv(path)
    c["cpu_pct_avg"] = pd.to_numeric(c["cpu_pct_avg"], errors="coerce")
    c["t"] = (c["ts_ms"] - int(open(base + ".start").read().strip())) / 1000.0
    return c[(c["t"] >= 0) & (c["t"] <= window)]["cpu_pct_avg"].mean()


def analyze_run(base, df, window, profile):
    """Tinh cac chi so cho mot lan do. Chi xet [0, window] giay de cac lan do so sanh duoc voi nhau."""
    jump, load_off = MARKS[profile]["jump"], MARKS[profile]["load_off"]
    before, after = df[df["t"] < 0], df[(df["t"] >= 0) & (df["t"] <= window)]
    at_jump = df[df["t"] < jump]
    start_desired = at_jump["desired"].iloc[-1] if len(at_jump) else after["desired"].iloc[0]
    up = after[(after["t"] >= jump) & (after["desired"] > start_desired)]
    peak = after["ready"].max()
    base_ready = before["ready"].iloc[-1] if len(before) else after["ready"].iloc[0]
    down = after[(after["t"] > load_off) & (after["ready"] <= base_ready)]
    s = json.load(open(base + ".summary.json"))
    return {
        "react_s": up["t"].iloc[0] - jump if len(up) else float("nan"),         # tai tang -> desired tang lan dau
        "full_s": after[after["ready"] >= peak]["t"].iloc[0] - jump,            # tai tang -> ready dat muc cao nhat
        "peak_ready": peak,
        "scale_down_s": down["t"].iloc[0] - load_off if len(down) else float("nan"),  # het tai -> ve muc ban dau
        "pod_seconds": (after["ready"] * after["t"].diff().fillna(0)).sum(),  # chi phi tai nguyen
        "cpu_pct_avg": cpu_mean(base, window),                                   # CPU TB cua cum (%)
        "p95_ms": metric(s, "http_req_duration", "p(95)"),
        "p99_ms": metric(s, "http_req_duration", "p(99)"),
        "error_rate": metric(s, "http_req_failed", "value"),
        "dropped": metric(s, "dropped_iterations", "count", 0),  # request k6 khong kip gui: so lieu tai that thap hon ke hoach
    }


def hpa_vs_keda(folder):
    os.makedirs(OUT, exist_ok=True)
    runs = {}
    for csv in sorted(glob.glob(os.path.join(folder, "*_run*.csv"))):
        base = csv[:-4]
        m = re.match(r"(hpa|keda)_(\w+)_run(\d+)$", os.path.basename(base))
        if not m or m.group(2) not in MARKS:
            continue
        try:
            df = load_run(base)
            json.load(open(base + ".summary.json"))
        except FileNotFoundError as e:
            print(f"bo qua {os.path.basename(base)}: thieu file {e.filename}")
            continue
        runs[(m.group(1), m.group(2), int(m.group(3)))] = (base, df)
    # cac lan do cua cung kich ban dung chung mot cua so thoi gian = lan ghi ngan nhat
    window = {}
    for (tool, profile, run), (base, df) in runs.items():
        window[profile] = min(window.get(profile, float("inf")), df["t"].max())
    rows, series = [], {}
    for (tool, profile, run), (base, df) in runs.items():
        rows.append({"tool": tool, "profile": profile, "run": run, **analyze_run(base, df, window[profile], profile)})
        series[(tool, profile, run)] = df
    for profile, w in window.items():
        print(f"kich ban {profile}: cua so so sanh = {w:.0f} giay (lan ghi ngan nhat)")
    if not rows:
        sys.exit("khong co lan do nao du 3 file .csv/.start/.summary.json")

    res = pd.DataFrame(rows)
    res.to_csv(os.path.join(OUT, "per_run.csv"), index=False)
    agg = res.drop(columns="run").groupby(["profile", "tool"]).agg(["mean", "std"])
    agg.to_csv(os.path.join(OUT, "summary.csv"))
    print(agg.round(2).to_string())

    for profile in sorted(res["profile"].unique()):
        fig, ax = plt.subplots(figsize=(8, 4))
        for (tool, p, run), df in series.items():
            if p == profile:
                ax.step(df["t"], df["ready"], where="post", alpha=0.5, color=COLORS[tool],
                        label=tool.upper() if run == 1 else None)
        ax.axvline(0, color="gray", lw=0.8, ls="--")
        ax.set_xlabel("giay (0 = bat dau tai)")
        ax.set_ylabel("so pod Ready")
        ax.set_title(f"So pod theo thoi gian - {profile}")
        ax.legend()
        fig.tight_layout()
        fig.savefig(os.path.join(OUT, f"pods_{profile}.png"), dpi=150)
        plt.close(fig)

    ax = res.groupby(["profile", "tool"])["p95_ms"].mean().unstack().plot.bar(figsize=(7, 4))
    ax.set_ylabel("p95 (ms)")
    ax.set_title("p95 theo kich ban")
    ax.figure.tight_layout()
    ax.figure.savefig(os.path.join(OUT, "p95_by_profile.png"), dpi=150)
    print("da ghi vao", OUT)


def coldstart(files):
    os.makedirs(OUT, exist_ok=True)
    data = {}
    for f in files:
        df = pd.read_csv(f, comment="#")
        # Ten file do coldstart.sh ghi: <function>-YYYYMMDD-HHMMSS[...].csv. Bo phan ngay gio o CUOI,
        # khong cat o dau gach ngang dau tien (data-transform se thanh "data").
        stem = os.path.basename(f)
        name = re.sub(r"-\d{8}-\d{6}.*$", "", stem)
        if name == stem:  # ten file khong theo mau tren
            name = os.path.splitext(stem)[0]
        if name in data:  # hai lan do cung function: giu ca hai, khong ghi de
            name = os.path.splitext(stem)[0]
        data[name] = df["elapsed_ms"].iloc[1:]  # bo lan do dau
    fig, ax = plt.subplots(figsize=(max(6, 2 * len(data)), 4))
    ax.boxplot(list(data.values()), tick_labels=list(data.keys()))
    if max(len(k) for k in data) > 14:  # nhan dai thi xoay cho khoi chong len nhau
        plt.setp(ax.get_xticklabels(), rotation=20, ha="right")
    ax.set_ylabel("cold-start (ms)")
    ax.set_title("Cold-start (bo lan do dau)")
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "coldstart_box.png"), dpi=150)
    print("da ghi", os.path.join(OUT, "coldstart_box.png"))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "hpa-vs-keda":
        hpa_vs_keda(sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "results", "hpa-vs-keda"))
    elif len(sys.argv) >= 3 and sys.argv[1] == "coldstart":
        coldstart(sys.argv[2:])
    else:
        sys.exit(__doc__)
