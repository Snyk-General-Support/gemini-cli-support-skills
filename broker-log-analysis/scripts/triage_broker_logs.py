#!/usr/bin/env python3
"""
Best-effort triage for Broker deployment JSON logs.

Outputs:
- error_count
- unique snyk-request-id values
- earliest error record per request id (timestamp, message snippet)
- Datadog links around the earliest timestamp

Assumptions:
- Logs are JSON objects either as JSON Lines (.jsonl / .log with one JSON per line)
  or as a single JSON array.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
import urllib.parse
from dataclasses import dataclass
from typing import Any, Dict, Iterable, Iterator, List, Optional, Tuple


DEFAULT_DATADOG_BASE_URL = "https://app.datadoghq.com/logs"

# Matches your Datadog "masked token" URL query pattern:
#   query=%40maskedToken%3A4char-...-4char
DEFAULT_MASKED_TOKEN_QUERY_TEMPLATE = "@maskedToken:{masked_token}"

# Matches your Datadog "request IDs" URL query pattern (REF_ID substituted):
#   @internalRequestId:REF_ID OR @req.requestId:REF_ID OR ...
DEFAULT_REQUEST_ID_QUERY_TEMPLATE = (
    "@internalRequestId:{request_id} OR "
    "@req.requestId:{request_id} OR "
    "@session_id:{request_id} OR "
    "@requestId:{request_id} OR "
    "@sastRequestId:{request_id} OR "
    "@requestHeaders.x-request-id:{request_id} OR "
    "@analytics-service.interaction.id:\"urn:snyk:interaction:{request_id}\""
)
DEFAULT_WINDOW_SECONDS = 15 * 60


def parse_ts(value: Any) -> Optional[float]:
    """Return epoch seconds or None if not parseable."""
    if value is None:
        return None

    # Numeric timestamps
    if isinstance(value, (int, float)):
        v = float(value)
        # Heuristic: ms vs s
        if v > 1e12:
            return v / 1000.0
        return v

    if isinstance(value, str):
        s = value.strip()
        if not s:
            return None

        # Common ISO formats
        # datetime.fromisoformat doesn't like trailing 'Z' in older Python versions
        s2 = s.replace("Z", "+00:00")
        try:
            parsed = dt.datetime.fromisoformat(s2)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return parsed.timestamp()
        except ValueError:
            return None

    return None


def extract_timestamp(record: Dict[str, Any]) -> Optional[float]:
    for key in [
        "timestamp",
        "ts",
        "time",
        "eventTime",
        "event_time",
        "datadog_timestamp",
        "@timestamp",
    ]:
        if key in record:
            ts = parse_ts(record.get(key))
            if ts is not None:
                return ts
    return None


def extract_request_id(record: Dict[str, Any]) -> Optional[str]:
    # Look for keys like snyk-request-id, snykRequestId, snyk_request_id, etc.
    for k, v in record.items():
        kl = str(k).lower().replace("_", "-")
        if "snyk" in kl and "request" in kl and "id" in kl:
            if isinstance(v, str):
                v2 = v.strip()
                return v2 if v2 else None
            if v is not None:
                return str(v)
    return None


def looks_like_error(record: Dict[str, Any]) -> bool:
    level = (
        record.get("level")
        or record.get("severity")
        or record.get("log.level")
        or record.get("logger.level")
    )
    if isinstance(level, str) and level.strip().lower() in {"error", "err", "fatal"}:
        return True

    # Message/error fields
    msg_parts: List[str] = []
    for k in ["message", "msg", "error", "exception", "stack", "reason"]:
        v = record.get(k)
        if isinstance(v, str) and v.strip():
            msg_parts.append(v.strip())
    msg = " ".join(msg_parts).lower()

    # Heuristic: if message contains "error" or common error markers
    return any(token in msg for token in ["error", "exception", "upstream", "failed", "fail"])


def extract_message_snippet(record: Dict[str, Any], max_len: int = 200) -> str:
    for k in ["message", "msg", "error", "exception"]:
        v = record.get(k)
        if isinstance(v, str) and v.strip():
            s = v.strip()
            return s[:max_len] + ("…" if len(s) > max_len else "")

    # Fall back to serializing part of the record
    try:
        s = json.dumps(record, ensure_ascii=False)
        return s[:max_len] + ("…" if len(s) > max_len else "")
    except Exception:
        return "(unable to extract message)"


@dataclass
class RecordRef:
    request_id: str
    ts: Optional[float]
    message: str
    source_file: str
    line_no: Optional[int]


def iter_json_records(path: str) -> Iterator[Tuple[Dict[str, Any], str, Optional[int]]]:
    """Yield (record, filename, line_no)."""
    if os.path.isdir(path):
        for root, _, files in os.walk(path):
            for name in files:
                if name.lower().endswith((".json", ".jsonl", ".log", ".txt")):
                    yield from iter_json_records(os.path.join(root, name))
        return

    filename = path
    with open(filename, "r", encoding="utf-8", errors="replace") as f:
        # Try to parse as line-delimited JSON first
        is_lines = True
        first_nonempty = None
        for line_no, line in enumerate(f, start=1):
            if first_nonempty is None and line.strip():
                first_nonempty = line.strip()
            if line.strip():
                try:
                    rec = json.loads(line)
                    if isinstance(rec, dict):
                        yield rec, filename, line_no
                    else:
                        is_lines = is_lines and False
                except json.JSONDecodeError:
                    is_lines = False
                    break
            if first_nonempty and is_lines is False:
                break

        # If we couldn't parse as lines, try whole-file JSON (array or object)
    if is_lines is False:
        with open(filename, "r", encoding="utf-8", errors="replace") as f2:
            text = f2.read().strip()
            if not text:
                return
            data = json.loads(text)
            if isinstance(data, list):
                for idx, rec in enumerate(data):
                    if isinstance(rec, dict):
                        yield rec, filename, idx
            elif isinstance(data, dict):
                yield data, filename, None


def build_datadog_link(
    base_url: str,
    query_template: str,
    request_id: str,
    earliest_ts: Optional[float],
    window_seconds: int,
) -> str:
    query = query_template.format(request_id=request_id)
    query_enc = urllib.parse.quote_plus(query)

    if earliest_ts is None:
        return f"{base_url}?query={query_enc}"

    # Datadog examples typically use milliseconds epoch for from_ts/to_ts.
    from_ts = int((earliest_ts - window_seconds) * 1000)
    to_ts = int((earliest_ts + window_seconds) * 1000)
    return f"{base_url}?query={query_enc}&from_ts={from_ts}&to_ts={to_ts}"


def main() -> int:
    p = argparse.ArgumentParser(description="Triage Broker JSON logs and generate Datadog links.")
    p.add_argument("--logs", required=True, help="Path to Broker logs file or directory")
    p.add_argument("--out", required=True, help="Output path for broker_triage.json")
    p.add_argument("--datadog-base-url", default=DEFAULT_DATADOG_BASE_URL)
    p.add_argument(
        "--datadog-request-id-query-template",
        default=DEFAULT_REQUEST_ID_QUERY_TEMPLATE,
        help="Template where {request_id} will be substituted",
    )
    p.add_argument(
        "--datadog-time-window-seconds",
        type=int,
        default=DEFAULT_WINDOW_SECONDS,
        help="± window for from_ts/to_ts",
    )
    args = p.parse_args()

    records_processed = 0
    error_records = 0

    earliest_by_request_id: Dict[str, RecordRef] = {}

    for rec, filename, line_no in iter_json_records(args.logs):
        records_processed += 1
        if not isinstance(rec, dict):
            continue
        if not looks_like_error(rec):
            continue

        error_records += 1
        request_id = extract_request_id(rec)
        if not request_id:
            continue

        ts = extract_timestamp(rec)
        message = extract_message_snippet(rec)
        current = RecordRef(
            request_id=request_id,
            ts=ts,
            message=message,
            source_file=filename,
            line_no=line_no,
        )

        prev = earliest_by_request_id.get(request_id)
        if prev is None:
            earliest_by_request_id[request_id] = current
        else:
            # Prefer earliest timestamp when both exist; otherwise keep the first with a timestamp.
            if prev.ts is not None and current.ts is not None:
                if current.ts < prev.ts:
                    earliest_by_request_id[request_id] = current
            elif prev.ts is None and current.ts is not None:
                earliest_by_request_id[request_id] = current

    request_ids = sorted(earliest_by_request_id.keys())

    earliest_errors = {}
    datadog_links = {}
    for rid in request_ids:
        ref = earliest_by_request_id[rid]
        iso_ts = None
        if ref.ts is not None:
            iso_ts = dt.datetime.fromtimestamp(ref.ts, tz=dt.timezone.utc).isoformat()
        earliest_errors[rid] = {
            "earliest_ts_epoch": ref.ts,
            "earliest_ts_iso": iso_ts,
            "message_snippet": ref.message,
            "source_file": ref.source_file,
            "line_no": ref.line_no,
        }
        datadog_links[rid] = build_datadog_link(
            base_url=args.datadog_base_url,
            query_template=args.datadog_request_id_query_template,
            request_id=rid,
            earliest_ts=ref.ts,
            window_seconds=args.datadog_time_window_seconds,
        )

    out_obj = {
        "input_logs_path": args.logs,
        "records_processed": records_processed,
        "error_records_found": error_records,
        "unique_snyk_request_ids": request_ids,
        "earliest_errors_by_request_id": earliest_errors,
        "datadog_links_by_request_id": datadog_links,
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out_obj, f, indent=2, ensure_ascii=False)

    # Print a short summary for the agent
    print(f"Processed records: {records_processed}")
    print(f"Error records: {error_records}")
    print(f"Unique snyk-request-id: {len(request_ids)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

