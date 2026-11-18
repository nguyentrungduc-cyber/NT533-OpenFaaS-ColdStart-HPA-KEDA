#!/usr/bin/env python3
"""Phan tich ket qua HPA vs KEDA (va ve boxplot cold-start).

Du lieu vao, trong load-testing/results/hpa-vs-keda/, moi lan do co 3 file cung ten
<tool>_<profile>_run<N>, vi du hpa_spike_run1:
  .csv           do record-replicas.sh ghi (ts_ms,ready,desired)
  .start         moc bat dau tai (date +%s%3N, ghi ngay truoc khi chay k6)
  .summary.json  do k6 --summary-export (can --summary-trend-stats co p(99))

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


def metric(summary, name, key):
    m = summary["metrics"][name]
    return m.get("values", m)[key]  # k6 ban cu co "values", ban moi khong


def analyze_run(base):
    """Tinh cac chi so cho mot lan do. base = duong dan khong co duoi file."""
    df = pd.read_csv(base + ".csv")
    df["ready"] = pd.to_numeric(df["ready"], errors="coerce").fillna(0)
    df["desired"] = pd.to_numeric(df["desired"], errors="coerce")
    t0 = int(open(base + ".start").read().strip())
    df["t"] = (df["ts_ms"] - t0) / 1000.0
    before, after = df[df["t"] < 0], df[df["t"] >= 0]
    start_desired = before["desired"].iloc[-1] if len(before) else after["desired"].iloc[0]
    up = after[after["desired"] > start_desired]
    peak = after["ready"].max()
    s = json.load(open(base + ".summary.json"))
    return df, {
        "react_s": up["t"].iloc[0] if len(up) else float("nan"),  # tai tang -> desired tang lan dau
        "full_s": after[after["ready"] >= peak]["t"].iloc[0],     # tai tang -> ready dat muc cao nhat
        "peak_ready": peak,
        "pod_seconds": (after["ready"] * after["t"].diff().fillna(0)).sum(),  # chi phi tai nguyen
        "p95_ms": metric(s, "http_req_duration", "p(95)"),
        "p99_ms": metric(s, "http_req_duration", "p(99)"),
        "error_rate": metric(s, "http_req_failed", "value"),
    }


def hpa_vs_keda(folder):
    os.makedirs(OUT, exist_ok=True)
    rows, series = [], {}
    for csv in sorted(glob.glob(os.path.join(folder, "*_run*.csv"))):
        base = csv[:-4]
        m = re.match(r"(hpa|keda)_(\w+)_run(\d+)$", os.path.basename(base))
        if not m:
            continue
        tool, profile, run = m.group(1), m.group(2), int(m.group(3))
        try:
            df, r = analyze_run(base)
        except FileNotFoundError as e:
            print(f"bo qua {os.path.basename(base)}: thieu file {e.filename}")
            continue
        rows.append({"tool": tool, "profile": profile, "run": run, **r})
        series[(tool, profile, run)] = df
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
        data[os.path.basename(f).split("-")[0]] = df["elapsed_ms"].iloc[1:]  # bo lan do dau
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.boxplot(list(data.values()), tick_labels=list(data.keys()))
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
