---
name: broker-log-analysis
description: Parse Broker deployment JSON logs to find errors, extract any `snyk-request-id` values, locate the first failing instances, generate Datadog links for investigation, and prepare a pre-escalation readiness checklist.
---

# Broker Log Analysis (Triage + Escalation Prep)

## Workflow

1. Use the `set-new-case` skill to create a new case folder.
   - Capture the created directory path into `CASE_DIR` (so later steps can write into it).
2. Ask the user for the path to the Broker deployment logs (JSON), as `BROKER_LOGS_PATH`.
3. Move the broker logs into the case folder:
   - If `BROKER_LOGS_PATH` is a file: move it into `"$CASE_DIR/"` (keep the original basename) and set `BROKER_LOGS_PATH` to the new location.
   - If `BROKER_LOGS_PATH` is a directory: move it into `"$CASE_DIR/broker_logs/"` (so the triage script can read the whole directory) and set `BROKER_LOGS_PATH` to `"$CASE_DIR/broker_logs"`.
4. Look for error records and extract any `snyk-request-id` values listed on those errors.
5. For each `snyk-request-id`, find the **first instance** (earliest timestamp in the logs) and generate a Datadog link around that time window.

Datadog link default structure (unless overridden):
- Base: `https://app.datadoghq.com/logs`
- Query (Datadog request id lookup): `@internalRequestId:{request_id} OR @req.requestId:{request_id} OR @session_id:{request_id} OR @requestId:{request_id} OR @sastRequestId:{request_id} OR @requestHeaders.x-request-id:{request_id} OR @analytics-service.interaction.id:"urn:snyk:interaction:{request_id}"`
- Window: +/- 15 minutes around the first error timestamp (use `from_ts/to_ts` only when timestamps exist).

Masked broker token lookup (for broker identity):
- Query: `@maskedToken:{masked_token}` (matches the field used in the Datadog maskedToken URL you provided).

6. Run triage script to produce `broker_triage.json` (inside `CASE_DIR`):

   ```bash
   python3 broker-log-analysis/scripts/triage_broker_logs.py \
     --logs "$BROKER_LOGS_PATH" \
     --out "$CASE_DIR/broker_triage.json"
   ```

I want to also make sure that you prepare the following to see if this qualifies for an escalation:

🚀 Snyk Broker Triage & Troubleshooting Guide

Internal Note: This document defines the "Definition of Ready" for escalating Broker issues to the Access Engineering team. Following these steps ensures faster resolution for customers and prevents "ping-pong" on tickets. Support driven troubleshooting guide here.

✅ Mandatory Pre-Escalation Checklist



Before escalating to Access, ensure the following data is attached to the Jira ticket. Escalations missing these items will be returned for further triage.

[ ] Broker Logs: Collected in .json format (not screenshots).

[ ] Confirm the expected Behaviour: Identify what the expected behaviour is, and what’s not working from the customer’s perspective (or from our Snyk logs).

[ ] Deployment Config: The full docker run command, values.yaml (Helm) or install command.

[ ] Preflight Results: Logs from the Broker Client restart.

[ ] Connection Proof: Confirmation that a process in the same host/container can reach the SCM (e.g., GitHub/GitLab).

[ ] Network Diagram: For connection issues, a map of all Proxies/Load Balancers between Snyk and the Broker.

[ ] Log Rehydration: If using Datadog, please check the time to live on the logs (14 days). If they are close to expiring, please rehydrate, and send engineering a link to the rehydrated logs.

🔍 Rapid Triage: Finding the Needle in Datadog

1. Identify the Specific Broker

Use the Masked Broker Token (first-4...last-4).

Query: @maskedToken:aaaa-...-bbbb

Finding the Token: Search actingOrgPublicId:<org_id> in Datadog. The token is in the @maskedToken field.

Pro Tip: If multiple clients exist, verify the token via the Admin Panel.

2. Check Connection Health

If you see...

It means...

Your Next Move (Action)

clientId changes every few minutes

The container itself is dying.

Ask customer for K8s/Docker events or OOM (Out of Memory) logs.

Same clientId, but many "New connection" logs

The process is alive, but the network is dropping.

Ask customer to check Load Balancer/Proxy timeouts (must be 3600s).

No logs at all in Datadog

The Broker isn't even reaching Snyk.

Check the BROKER_SERVER_URL and Firewall Egress rules.

timeoutMs is very low (e.g., < 60000)

Something is forcefully killing the Websocket.

Check for Cloud Load Balancer defaults (GCP/AWS).

🛠 Troubleshooting Common Scenarios

🌐 Connectivity & Networking

Websocket Drops: Look for the timeoutMs field.

Short life/High frequency = Local network issue.

Solution: Ensure Load Balancer/Proxy timeouts are set to at least 3600s.

Missing Data Flow: Data returns via HTTP, not the Websocket. If logs show requests but no data, check the customer's egress rules for HTTP.

Graceful vs. Forceful: Search for Shutting down client. If missing but client restarted, the OS/Orchestrator killed it (OOM, etc.).

❌ Error Code Decoder

Error

Source

Interpretation

no-connection

Broker client websocket was down when trying to do a brokered action

Broker Client is down or Websocket is severed.

4XX / 5XX

Customer SCM

The SCM (GitHub/etc) is returning the error.

UPSTREAM BROKER SERVER FAILURE

Snyk Side

This is a Snyk-side infrastructure issue.

Stale auth

Snyk Side

Broker Server is killing old/invalid sessions.

404 with /not-a-real-commit

Normal

Noise from Snyk agents; can be ignored in DD.

💡 Engineering Recommendations for Customers

If the customer is experiencing instability, suggest these "Big Wins" before escalating:

Enable HA Mode: If they haven't already, this is the #1 way to prevent downtime.

Turn Off Body Logging: If the client is crashing under load, body logging may be the culprit.

Healthcheck Thresholds: Ensure the orchestrator isn't killing the container too early during a busy event loop.

