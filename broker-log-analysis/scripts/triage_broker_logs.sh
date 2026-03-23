#!/usr/bin/env bash
set -euo pipefail

# triage_broker_logs.sh
# Pure jq + bash implementation (no python parsing / no python deps).

DEFAULT_DATADOG_BASE_URL="https://app.datadoghq.com/logs"
DEFAULT_REQUEST_ID_QUERY_TEMPLATE='@internalRequestId:{request_id} OR @req.requestId:{request_id} OR @session_id:{request_id} OR @requestId:{request_id} OR @sastRequestId:{request_id} OR @requestHeaders.x-request-id:{request_id} OR @analytics-service.interaction.id:"urn:snyk:interaction:{request_id}"'
DEFAULT_MASKED_TOKEN_QUERY_TEMPLATE='@maskedToken:{masked_token}'
DEFAULT_WINDOW_SECONDS=$((15 * 60))

LOGS_PATH=""
OUT_PATH=""
DATADOG_BASE_URL="${DATADOG_BASE_URL:-$DEFAULT_DATADOG_BASE_URL}"
DATADOG_REQUEST_ID_QUERY_TEMPLATE="${DATADOG_REQUEST_ID_QUERY_TEMPLATE:-$DEFAULT_REQUEST_ID_QUERY_TEMPLATE}"
DATADOG_MASKED_TOKEN_QUERY_TEMPLATE="${DATADOG_MASKED_TOKEN_QUERY_TEMPLATE:-$DEFAULT_MASKED_TOKEN_QUERY_TEMPLATE}"
DATADOG_TIME_WINDOW_SECONDS="${DATADOG_TIME_WINDOW_SECONDS:-$DEFAULT_WINDOW_SECONDS}"

usage() {
  cat <<EOF
usage: triage_broker_logs.sh --logs LOGS_PATH --out OUT_PATH
  [--datadog-base-url URL]
  [--datadog-request-id-query-template TEMPLATE]
  [--datadog-masked-token-query-template TEMPLATE]
  [--datadog-time-window-seconds N]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --logs) LOGS_PATH="${2:-}"; shift 2 ;;
    --out) OUT_PATH="${2:-}"; shift 2 ;;
    --datadog-base-url) DATADOG_BASE_URL="${2:-}"; shift 2 ;;
    --datadog-request-id-query-template) DATADOG_REQUEST_ID_QUERY_TEMPLATE="${2:-}"; shift 2 ;;
    --datadog-masked-token-query-template) DATADOG_MASKED_TOKEN_QUERY_TEMPLATE="${2:-}"; shift 2 ;;
    --datadog-time-window-seconds) DATADOG_TIME_WINDOW_SECONDS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "${LOGS_PATH}" || -z "${OUT_PATH}" ]]; then
  usage >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Missing jq. Install jq to run this script." >&2
  exit 2
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

emit_records_from_file() {
  local file="$1"
  # Try parse as whole JSON first; if it fails, assume JSON Lines.
  if jq -e '.' "${file}" >/dev/null 2>&1; then
    jq -c --arg file "${file}" '
      (if type=="array" then . else [.] end)
      | .[]
      | . + { "__source_file": $file }
    ' "${file}" >> "${tmp}"
  else
    jq -cR --arg file "${file}" '
      split("\n")
      | map(select(length>0))
      | map(fromjson?)
      | map(select(.!=null))
      | map(. + { "__source_file": $file })
      | .[]
    ' < "${file}" >> "${tmp}"
  fi
}

if [[ -d "${LOGS_PATH}" ]]; then
  shopt -s globstar nullglob
  for f in "${LOGS_PATH}"/**/*; do
    [[ -f "${f}" ]] || continue
    ext="${f##*.}"
    case "${ext,,}" in
      json|jsonl|log|txt) emit_records_from_file "${f}" ;;
    esac
  done
  shopt -u globstar nullglob
else
  emit_records_from_file "${LOGS_PATH}"
fi

mkdir -p "$(dirname "${OUT_PATH}")" 2>/dev/null || true

if [[ ! -s "${tmp}" ]]; then
  jq -n --arg logs "${LOGS_PATH}" '{
    input_logs_path: $logs,
    records_processed: 0,
    error_records_found: 0,
    unique_snyk_request_ids: [],
    earliest_errors_by_request_id: {},
    datadog_links_by_request_id: {},
    unique_masked_tokens: [],
    earliest_errors_by_masked_token: {},
    datadog_links_by_masked_token: {}
  }' > "${OUT_PATH}"
  exit 0
fi

jq -s \
  --arg base_url "${DATADOG_BASE_URL}" \
  --arg request_id_query_template "${DATADOG_REQUEST_ID_QUERY_TEMPLATE}" \
  --arg masked_token_query_template "${DATADOG_MASKED_TOKEN_QUERY_TEMPLATE}" \
  --arg logs_path "${LOGS_PATH}" \
  --argjson window_seconds "${DATADOG_TIME_WINDOW_SECONDS}" '
  def ts_val:
    (.timestamp? // .ts? // .time? // .eventTime? // .event_time? // .datadog_timestamp? // ."@timestamp"?);

  def ts_epoch:
    if ts_val == null then null
    elif (ts_val|type) == "number" then
      (if ts_val > 1000000000000 then (ts_val/1000) else ts_val end)
    elif (ts_val|type) == "string" then
      (fromdateiso8601? // null)
    else null end;

  def level_str:
    (.level? // .severity? // ."log.level"? // ."logger.level"? // (.logger.level? // empty) // (.log.level? // empty));

  def msg_blob:
    if (.message? | type)=="string" then .message
    elif (.msg? | type)=="string" then .msg
    elif (.error? | type)=="string" then .error
    elif (.exception? | type)=="string" then .exception
    elif (.reason? | type)=="string" then .reason
    elif (.stack? | type)=="string" then .stack
    else null end;

  def msg_lower: ((msg_blob // "") | ascii_downcase);

  def is_error:
    (
      (level_str|type)=="string"
      and (level_str | ascii_downcase | test("error|err|fatal"))
    )
    or
    (msg_lower | test("error|exception|upstream|failed|fail"));

  def request_id:
    (
      [
        to_entries[]
        | select((.key|ascii_downcase)|test("snyk"))
        | select((.key|ascii_downcase)|test("request"))
        | select((.key|ascii_downcase)|test("id"))
        | .value
        | (if type=="string" then . else tostring end)
        | select(length>0)
      ] | first
    );

  def masked_token:
    (
      (.maskedToken? // .masked_token? // null)
      // (
        [
          to_entries[]
          | select((.key|ascii_downcase)|test("masked"))
          | select((.key|ascii_downcase)|test("token"))
          | .value
          | (if type=="string" then . else tostring end)
          | select(length>0)
        ] | first
      )
    );

  def msg_snippet:
    (msg_blob // "(unable to extract message)") as $m
    | ($m|tostring) as $s
    | ($s[0:200]) + (if ($s|length) > 200 then "…" else "" end);

  def datadog_link($templ; $token; $ts):
    (
      ($templ
        | gsub("\\{request_id\\}"; ($token|tostring))
        | gsub("\\{masked_token\\}"; ($token|tostring))
      ) as $q
      | ($q | @uri) as $qenc
      | if $ts == null then
          ($base_url + "?query=" + $qenc)
        else
          ((($ts|floor) - $window_seconds) * 1000 | floor) as $from_ms
          | ((($ts|floor) + $window_seconds) * 1000 | floor) as $to_ms
          | ($base_url + "?query=" + $qenc + "&from_ts=" + ($from_ms|tostring) + "&to_ts=" + ($to_ms|tostring))
        end
    );

  def error_record:
    {
      ts: ts_epoch,
      message: msg_snippet,
      source_file: (.__source_file? // null),
      request_id: request_id,
      masked_token: masked_token
    };

  . as $records
  | (length) as $records_processed
  | ($records | map(select(is_error) | error_record)) as $errors_all
  | ($errors_all | length) as $error_records_found
  | ($errors_all | map(select(.request_id != null and (.request_id|tostring|length)>0) | .)) as $errors_req
  | ($errors_all | map(select(.masked_token != null and (.masked_token|tostring|length)>0) | .)) as $errors_mask

  | ($errors_req
      | map({rid:(.request_id|tostring), ts:.ts, message:.message, source_file:.source_file})
      ) as $errors_req_s

  | ($errors_req_s | reduce .[] as $e ({}; 
      .[$e.rid] =
        (if .[$e.rid] == null then $e
         elif ($e.ts != null and (.[ $e.rid ].ts == null or $e.ts < .[$e.rid].ts)) then $e
         elif ($e.ts == null and .[$e.rid].ts == null) then $e
         else .[$e.rid] end)
    )) as $earliest_by_request

  | ($earliest_by_request | keys | sort) as $request_ids

  | ($earliest_by_request
      | to_entries
      | map({ key: .key, value: { earliest_ts_epoch: .value.ts, earliest_ts_iso: (if .value.ts==null then null else (.value.ts | todate) end), message_snippet: .value.message, source_file: .value.source_file } })
      | from_entries
    ) as $earliest_errors_by_request

  | (reduce $request_ids[] as $rid ({}; . + { ($rid): datadog_link($request_id_query_template; $rid; $earliest_by_request[$rid].ts) })) as $datadog_links_by_request

  | ($errors_mask
      | map({mt:(.masked_token|tostring), ts:.ts, message:.message, source_file:.source_file})
    ) as $errors_mask_s

  | ($errors_mask_s | reduce .[] as $e ({}; 
      .[$e.mt] =
        (if .[$e.mt] == null then $e
         elif ($e.ts != null and (.[ $e.mt ].ts == null or $e.ts < .[$e.mt].ts)) then $e
         elif ($e.ts == null and .[$e.mt].ts == null) then $e
         else .[$e.mt] end)
    )) as $earliest_by_mask

  | ($earliest_by_mask | keys | sort) as $masked_tokens

  | ($earliest_by_mask
      | to_entries
      | map({ key: .key, value: { earliest_ts_epoch: .value.ts, earliest_ts_iso: (if .value.ts==null then null else (.value.ts | todate) end), message_snippet: .value.message, source_file: .value.source_file } })
      | from_entries
    ) as $earliest_errors_by_mask

  | (reduce $masked_tokens[] as $mt ({}; . + { ($mt): datadog_link($masked_token_query_template; $mt; $earliest_by_mask[$mt].ts) })) as $datadog_links_by_mask

  | {
      input_logs_path: $logs_path,
      records_processed: $records_processed,
      error_records_found: $error_records_found,
      unique_snyk_request_ids: $request_ids,
      earliest_errors_by_request_id: $earliest_errors_by_request,
      datadog_links_by_request_id: $datadog_links_by_request,
      unique_masked_tokens: $masked_tokens,
      earliest_errors_by_masked_token: $earliest_errors_by_mask,
      datadog_links_by_masked_token: $datadog_links_by_mask
    }
' "${tmp}" > "${OUT_PATH}"

echo "Done. Output: ${OUT_PATH}"
exit 0

