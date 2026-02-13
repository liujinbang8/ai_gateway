# SPEC.md - LLM Gateway v1.1 (WebFlux + MinIO + OIDC)

## 1. Base Paths
- OpenAI-compatible: `/openai/v1`
- Claude-compatible: `/claude/v1`
- Admin: `/admin`

## 2. Data-plane Authentication
- OpenAI: `Authorization: Bearer <api_key>`
- Claude: `x-api-key: <api_key>`

API key lookup:
- `key_hash = SHA-256(api_key + SERVER_SALT)`
- active + not expired + not revoked

Subject binding:
- owner_type: USER | APP
- owner_id
- dept_id

## 3. Model Types & Protocol Contracts
Supported model types:
- CHAT / EMBEDDING / RERANK / VL / OCR

OpenAI sync endpoints:
- `/chat/completions`, `/embeddings`, `/rerank`, `/responses`, `/ocr`

Claude sync endpoints:
- `/messages`, `/embeddings`, `/rerank`, `/ocr`

Unified async endpoints:
- `POST /jobs`
- `GET /jobs/{job_id}`
- `job_type`: CHAT | EMBEDDING | RERANK | VL | OCR | EMBEDDING_BATCH

## 4. Admin Authentication (OIDC)
- OIDC login for `/admin/**`
- AD-backed OIDC provider (Entra/ADFS/Keycloak/SSO)
- v1.1 does NOT include org/group auto-sync

## 5. Security Governance
Data-plane must enforce:
- Sensitive words
- Allow/Block lists
- Prompt injection detection
- Content safety policy

Actions:
- ALLOW / WARN / BLOCK

All hits must be recorded as security incidents.

## 6. File Upload & Storage (MinIO)
- OCR/VL endpoints accept multipart upload
- object key: `{yyyy}/{mm}/{dd}/{request_id}/{filename}`
- store file metadata in MySQL

## 7. Streaming
- OpenAI stream: SSE
- Claude stream: SSE
- always include `x-request-id`

## 8. Quota
- Monthly token cap per user and dept
- exceed -> `429 QUOTA_EXCEEDED`

## 9. Metering & Cost
- authoritative ledger: `usage_records`
- report granularity: USER_MODEL / DEPT_MODEL
- report periods: WEEK / MONTH / QUARTER

## 10. Logging / Tracing / Metrics
- ES metadata indexed for every request
- raw prompt/response default OFF, if ON must desensitize
- Tracing: `x-request-id` + `traceparent` propagation
- Metrics exported to Prometheus

