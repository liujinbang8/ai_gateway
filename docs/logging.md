# docs/logging.md - Elasticsearch Logging & Desensitization

## 1. Goals
- Every data-plane request MUST index metadata into Elasticsearch (ES).
- Raw prompt/response indexing is OPTIONAL, controlled by config.
- If raw indexing is enabled, content MUST be desensitized before indexing.
- Logs support:
  - audit (who called what)
  - troubleshooting (latency, errors)
  - cost governance (tokens, cost)
  - security governance (rule hits, block/warn decisions)

## 2. Index naming
Index prefix configurable: `llmgw.logging.es.indexPrefix` (default `llmgw-requests`)

Daily index:
- `{indexPrefix}-YYYY.MM.DD`
Example:
- `llmgw-requests-2026.02.13`

## 3. Document schema (fields)

### 3.1 Required metadata fields (MUST be indexed)
- `@timestamp` (ISO string)
- `request_id` (string)
- `trace_id` (string, optional)
- `base_path` (OPENAI | CLAUDE)
- `endpoint` (e.g. /chat/completions, /messages, /ocr)
- `http_method` (POST/GET)
- `status` (SUCCESS | FAILED)
- `error_code` (string, nullable)
- `error_message` (string, nullable; keep short)

Subject & auth:
- `api_key_id` (number)
- `subject_type` (USER | APP)
- `subject_id` (number)
- `dept_id` (number)
- `username` (string, optional)

Model routing:
- `requested_model` (string, nullable)
- `selected_model` (string)
- `selected_model_id` (number)
- `vendor` (string)
- `vendor_model_id` (string)
- `model_type` (CHAT | EMBEDDING | RERANK | VL | OCR)
- `routing_policy` (COST_FIRST | QUALITY_FIRST | LATENCY_FIRST | DIRECT)
- `fallback_used` (boolean)
- `fallback_chain` (array of model ids/names, optional)

Security:
- `security_rule_type` (SENSITIVE_WORD | PROMPT_INJECTION | ACCESS_LIST, optional)
- `security_action` (ALLOW | WARN | BLOCK, optional)
- `security_score` (number, optional)

Usage & cost:
- `input_tokens` (number)
- `output_tokens` (number)
- `total_tokens` (number)
- `cost_cny` (number)

Timing:
- `latency_ms` (number)
- `vendor_latency_ms` (number, optional)

Files / jobs:
- `file_ids` (array of numbers, optional)
- `job_id` (string, optional)
- `job_type` (OCR | VL | EMBEDDING_BATCH, optional)

Network:
- `client_ip` (string, optional)
- `user_agent` (string, optional)

### 3.2 Optional raw content fields (only if enabled)
Controlled by:
- `llmgw.logging.es.rawEnabled` (default false)

Raw fields:
- `raw_prompt` (string or object)
- `raw_response` (string or object)

NOTE:
- Raw fields MUST be desensitized before indexing.
- If rawEnabled=false, do not index raw fields at all.

## 4. Desensitization (PII masking)

### 4.1 Built-in masking rules
Apply in order (best-effort):

- Email:
  - pattern: `([a-zA-Z0-9_.+-]+)@([a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)`
  - replacement: `***@***`

- Phone (simple CN/TW patterns):
  - pattern: `(?<!\d)(1\d{10})(?!\d)` for CN mobile (example)
  - pattern: `(?<!\d)(09\d{8})(?!\d)` for TW mobile (example)
  - replacement: `***MASKED_PHONE***`

- ID card (CN 18-digit as example):
  - pattern: `(?<!\d)(\d{17}[0-9Xx])(?!\d)`
  - replacement: `***MASKED_ID***`

- Bank card (16-19 digits):
  - pattern: `(?<!\d)(\d{16,19})(?!\d)`
  - replacement: `***MASKED_BANK_CARD***`

### 4.2 Configurable extra regex
From `application-local.yml`:
- `llmgw.logging.es.desensitize.extraRegex[]` supports:
  - name
  - pattern
  - replacement

### 4.3 JSON-aware masking
If raw_prompt/raw_response are JSON objects:
- serialize to string, mask, and optionally store masked JSON string
- OR recursively traverse strings and mask
Choose one deterministic approach and document it in code.

## 5. What must NOT be logged
Even if rawEnabled=true:
- Vendor credentials (API keys/AKSK)
- Gateway API keys (never log full key; only api_key_id and partial fingerprint if needed)
- OIDC client secrets
- Any encryption keys

## 6. Failure handling
ES indexing is **best-effort**:
- If ES is down, do not fail the main request (data-plane).
- Record metric `es_index_failures_total` and log a warning (without raw content).
- Optionally buffer to local queue (out of v1 scope).

## 7. Retention & access (recommendation)
- Default retention: 30-90 days depending on compliance
- Access to raw content (if enabled) should be limited (admin-only + audited).
Even if admin data-permission isn't implemented in UI, keep the policy documented.

## 8. Correlation with MySQL metering
- MySQL `usage_records` is the authoritative ledger for billing.
- ES is used for search/troubleshooting and can store richer context.
- Link by `request_id` and `job_id`.
