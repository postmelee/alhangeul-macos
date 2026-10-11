#!/usr/bin/env python3
"""signed 확장 로그를 PID·request UUID로만 대응한다. 추정한 파일/캐시는 집계하지 않는다."""
import argparse
import collections
import datetime
import json
import math
import re
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUBSYSTEMS = {"com.postmelee.alhangeul.QLExtension", "com.postmelee.alhangeul.ThumbnailExtension"}
TRACE = re.compile(r"FontPerformance request=(\S+) kind=([A-Za-z][A-Za-z0-9.]*) startNanos=(\d+) endNanos=(\d+) ms=([\d.]+) success=(true|false|1|0)")
READY = re.compile(r"Thumbnail ready file=(\S+) policy=(\S+) cache=(\S+) requestedBucket=(\S+) matchedBucket=(\S+) backend=(\S+) fallback=(\S+) renderMs=([\d.]+) pixels=(\S+) context=(\S+) page=(\S+)")
METADATA = re.compile(r"Font metadata ready installedEnabled=(true|false) records=(\d+) managed=(\d+) metadataMs=([\d.]+)")


def immediate_callback_event(previous, row):
    # These logger calls and the trace execute synchronously on the same thread.
    # Do not match a nearby event from a different thread or a whole time window.
    if not previous or previous.get("processImageUUID") != row.get("processImageUUID"):
        return None
    try:
        before = datetime.datetime.fromisoformat(previous["timestamp"])
        after = datetime.datetime.fromisoformat(row["timestamp"])
    except (KeyError, ValueError):
        return None
    return previous.get("eventMessage", "") if 0 <= (after - before).total_seconds() <= 0.001 else None


def read_events(path):
    text = path.read_text()
    if text.lstrip().startswith("["):
        return json.loads(text)
    rows = []
    for line in text.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue  # log stream의 시작 안내는 JSON event가 아니다.
        if isinstance(value, dict):
            rows.append(value)
    return rows


def distribution(values):
    if not values:
        return {"count": 0}
    values = sorted(values)
    result = {"count": len(values), "minimum": values[0], "median": statistics.median(values), "maximum": values[-1]}
    if len(values) >= 10:
        result["p90"] = values[math.ceil(len(values) * 0.9) - 1]
    return result


def summarize(events):
    requests = collections.defaultdict(list)
    previous_by_thread = {}
    for row in events:
        if row.get("subsystem") not in SUBSYSTEMS:
            continue
        key = (row.get("processID"), row.get("subsystem"), row.get("threadID"))
        previous = previous_by_thread.get(key) if row.get("threadID") is not None else None
        previous_by_thread[key] = row
        match = TRACE.fullmatch(row.get("eventMessage", ""))
        if not match:
            continue
        request, kind, start, end, milliseconds, success = match.groups()
        start, end = int(start), int(end)
        item = {
            "kind": kind, "startNanos": start, "endNanos": end,
            "loggedMs": float(milliseconds), "success": success in ("true", "1"),
            "timestamp": row.get("timestamp"), "processImageUUID": row.get("processImageUUID")}
        message = immediate_callback_event(previous, row)
        if message:
            ready = READY.fullmatch(message) if kind == "thumbnail" else None
            metadata = METADATA.fullmatch(message) if kind == "metadata" else None
            if ready:
                names = ["document", "policy", "cache", "requestedBucket", "matchedBucket", "backend", "fallback", "renderMs", "pixels", "context", "page"]
                item["callback"] = dict(zip(names, ready.groups()))
                item["callbackEvidence"] = "immediate predecessor on same PID/subsystem/thread/image UUID; synchronous callback; <=1ms"
            if metadata:
                enabled, records, managed, _ = metadata.groups()
                item["installedEnabled"] = enabled == "true"
                item["records"] = int(records)
                item["managed"] = int(managed)
        requests[(row["processID"], row["subsystem"], request)].append(item)
    samples = []
    for (pid, subsystem, request), rows in sorted(requests.items()):
        metadata = [r for r in rows if r["kind"] == "metadata"]
        providers = [r for r in rows if r["kind"] in ("thumbnail", "preview")]
        sample = {"pid": pid, "subsystem": subsystem, "request": request, "events": rows,
                  "status": "unpaired", "cache": "unknown", "document": None,
                  "details": [r for r in rows if r["kind"] not in ("metadata", "thumbnail", "preview")]}
        if len(metadata) == 1 and len(providers) == 1:
            m, p = metadata[0], providers[0]
            sample["consumer"] = p["kind"]
            if "installedEnabled" in m:
                sample["installedEnabled"] = m["installedEnabled"]
            if "callback" in p:
                sample.update(p["callback"])
                sample["callbackEvidence"] = p["callbackEvidence"]
            images = {r["processImageUUID"] for r in rows if r["processImageUUID"] is not None}
            if len(images) > 1:
                sample["status"] = "invalidImageIdentity"
            elif p["startNanos"] <= m["startNanos"] <= m["endNanos"] <= p["endNanos"]:
                sample["metadataMs"] = (m["endNanos"] - m["startNanos"]) / 1_000_000
                sample["providerMs"] = (p["endNanos"] - p["startNanos"]) / 1_000_000
                sample["status"] = "success" if m["success"] and p["success"] else "failure"
                if sample["status"] == "success" and sample["providerMs"] > 0:
                    sample["metadataFraction"] = sample["metadataMs"] / sample["providerMs"]
            else:
                sample["status"] = "invalidInterval"
        elif len(metadata) > 1 or len(providers) > 1:
            sample["status"] = "ambiguous"
        samples.append(sample)
    groups = collections.defaultdict(list)
    for s in samples:
        groups[(s["pid"], s.get("consumer"), s["cache"], s.get("installedEnabled"))].append(s)
    summary = []
    for (pid, consumer, cache, enabled), rows in sorted(groups.items(), key=lambda item: str(item[0])):
        valid = [r for r in rows if r["status"] == "success"]
        summary.append({"pid": pid, "consumer": consumer, "cache": cache, "installedEnabled": enabled,
                        "statuses": dict(collections.Counter(r["status"] for r in rows)),
                        "metadataMs": distribution([r["metadataMs"] for r in valid]),
                        "providerMs": distribution([r["providerMs"] for r in valid]),
                        "metadataFraction": distribution([r["metadataFraction"] for r in valid])})
    return {"samples": samples, "summary": summary,
            "busyBoundaryAttempts": dict(collections.Counter(r["kind"] for sample in samples for r in sample["details"] if r["kind"].startswith("busy."))),
            "scope": "signed provider completion, not Finder screen paint; UUID interval pairing; callback attributes only from immediate same-thread synchronous event within 1ms; otherwise unknown"}


def self_test():
    def event(pid, request, kind, start, end, success="true"):
        return {"processID": pid, "subsystem": "com.postmelee.alhangeul.ThumbnailExtension",
                "eventMessage": f"FontPerformance request={request} kind={kind} startNanos={start} endNanos={end} ms={(end-start)/1e6:.6f} success={success}"}
    rows = [event(1, "a", "metadata", 10, 60), event(1, "b", "metadata", 30, 80),
            event(1, "b", "thumbnail", 20, 100), event(1, "a", "thumbnail", 0, 90),
            event(2, "a", "metadata", 1, 2), event(3, "c", "metadata", 5, 20),
            event(3, "c", "thumbnail", 0, 10), event(4, "d", "metadata", 1, 2),
            event(4, "d", "metadata", 1, 2), event(4, "d", "thumbnail", 0, 3),
            event(5, "e", "metadata", 1, 2, "false"), event(5, "e", "thumbnail", 0, 3)]
    rows += [event(1, "a", "catalogRefresh", 12, 40), event(5, "e", "busy.thumbnailRenderSlots", 1, 1, "false")]
    samples = summarize(rows)["samples"]
    assert collections.Counter(r["status"] for r in samples) == {"success": 2, "unpaired": 1, "invalidInterval": 1, "ambiguous": 1, "failure": 1}
    assert next(r for r in samples if r["pid"] == 1 and r["request"] == "a")["metadataMs"] == 50 / 1e6
    assert summarize(rows)["busyBoundaryAttempts"] == {"busy.thumbnailRenderSlots": 1}
    different_images = [dict(event(7, "g", "metadata", 1, 2), processImageUUID="first"),
                        dict(event(7, "g", "thumbnail", 0, 3), processImageUUID="second")]
    assert summarize(different_images)["samples"][0]["status"] == "invalidImageIdentity"
    foreign_subsystem = dict(event(7, "g", "thumbnail", 0, 3), subsystem="other")
    assert summarize([different_images[0], foreign_subsystem])["samples"][0]["status"] == "unpaired"
    ready = "Thumbnail ready file=test.hwpx policy=coreGraphicsOnly cache=exactHit requestedBucket=256x256 matchedBucket=256x256 backend=coreGraphics fallback=- renderMs=7.0 pixels=181x256 context=181x256 page=793x1122"
    for thread, gap, expected in [(9, 100, "exactHit"), (10, 100, "unknown"), (9, 5000, "unknown")]:
        a = event(6, "f", "metadata", 1, 2)
        b = event(6, "f", "thumbnail", 0, 3)
        b.update(threadID=9, timestamp=f"2026-10-10 00:00:00.{gap:06d}+0900", processImageUUID="probe")
        c = dict(b, eventMessage=ready, threadID=thread, timestamp="2026-10-10 00:00:00.000000+0900")
        assert summarize([a, c, b])["samples"][0]["cache"] == expected
    # An intervening same-thread event disqualifies the callback association.
    d = dict(c, eventMessage="unrelated")
    assert summarize([a, c, d, b])["samples"][0]["cache"] == "unknown"
    print("PASS: UUID/PID intervals and conservative same-thread callback attribution")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--events", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.events or not args.output:
        parser.error("--events와 --output이 필요합니다")
    output = args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / "build.noindex/task580"):
        raise SystemExit("Task 580 아래 새 결과 경로가 필요합니다")
    output.write_text(json.dumps(summarize(read_events(args.events)), indent=2) + "\n")
    print(output)


if __name__ == "__main__":
    main()
