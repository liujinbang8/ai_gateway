# docs/routing.md - Routing Policy & Fallback Rules

## 1. Goals
- Provide department-level default routing policies per model type.
- Support three policy templates:
  - COST_FIRST
  - QUALITY_FIRST
  - LATENCY_FIRST
- Support fallback across a model chain on vendor failure/timeout.
- Model authorization applies first; routing only selects among permitted models.

Non-goals (v1):
- No percentage-based traffic splitting (no gray release)
- No rate limiting
- No A/B testing

## 2. Inputs to routing
For each request, routing engine receives:

- subject: (USER/APP + id), dept_id
- base_path: OPENAI or CLAUDE (for compatibility only)
- endpoint and inferred model_type:
  - /chat/completions -> CHAT
  - /embeddings -> EMBEDDING
  - /ocr -> OCR
  - /messages (claude) -> CHAT (unless you implement separate VL)
- requested_model (optional)
- effective_models: authorized model set for the subject (post RBAC + key scope)
- security decision: request already passed allow/block security governance
- dept policy: from `dept_routing_policies` for (dept_id, model_type, policy_type)

## 3. Policy selection
If request specifies policy explicitly (optional future): ignore in v1.

In v1:
- Use department default policy_type for the given model_type.
- If no department default configured, use global default:
  - `llmgw.routing.defaultPolicyType` (default COST_FIRST)

## 4. Model selection rules

### 4.1 Direct model specified
If request includes `model`:
1. Validate that requested model exists and is enabled.
2. Validate authorization: requested model ∈ effective_models.
3. Route directly to that model.
4. Fallback behavior (v1 recommendation):
   - If direct model specified, DO NOT fallback to other models by default
   - Reason: caller explicitly chose a model and may depend on its behavior
   - Optional config `llmgw.routing.allowFallbackOnDirectModel=false`

Return errors:
- model not found/disabled -> 400 MODEL_NOT_FOUND
- not authorized -> 403 MODEL_FORBIDDEN

### 4.2 No model specified (policy routing)
If model not specified:
1. Load department policy chain:
   - `dept_routing_policies.model_chain` is an ordered JSON list of model_ids
2. Filter chain:
   - keep only models that are enabled AND in effective_models AND match model_type
3. If filtered chain empty -> 403 NO_MODEL_AVAILABLE
4. Choose first model in chain as primary.
5. Call primary, with fallback rules below.

## 5. Fallback rules

### 5.1 What triggers fallback
Fallback is attempted when:
- Request times out (gateway timeout or vendor timeout)
- Vendor returns 5xx
- Vendor returns network errors / DNS / TLS handshake failures
- Vendor returns malformed response (parsing failure)

Fallback is NOT attempted when (v1 recommendation):
- Authorization failures (403)
- Input validation errors (400)
- Quota exceeded (429 from gateway)
- Vendor returns explicit client-side errors that indicate request is invalid (most 4xx)
- Vendor returns content policy refusal (treat as success with refusal response)

429 vendor rate-limit:
- Decision point:
  - Option A (recommended for stability): allow fallback on vendor 429
  - Option B (recommended for cost predictability): do NOT fallback on vendor 429
v1 default: **allow fallback on vendor 429** ONLY if next model is in same vendor family or configured explicitly.
(If you want simpler: choose either always fallback or never fallback on 429 and implement that.)

### 5.2 Fallback chain traversal
- Attempt models in order from the filtered chain.
- Stop at first successful response.
- Record in logs:
  - fallback_used=true
  - fallback_chain=[...]
  - selected_model=<the model that succeeded>
- If all models fail:
  - return 502 VENDOR_ERROR (OpenAI/Claude compatible error envelope)

### 5.3 Timeout & retry policy
Retries inside a single model call (same vendor/model) are limited:
- max retries: 1 (configurable)
- exponential backoff (e.g., 200ms -> 500ms)
Rationale: avoid amplifying traffic.

Timeouts (configurable):
- connectTimeoutMs: 3000
- readTimeoutMs: 60000 (non-stream)
- stream read timeout may be longer (implementation-dependent)

## 6. Department policy data model
Table: `dept_routing_policies`

- dept_id
- model_type (CHAT/EMBEDDING/RERANK/VL/OCR)
- policy_type (COST_FIRST/QUALITY_FIRST/LATENCY_FIRST)
- model_chain: JSON list of model_ids

Example `model_chain`:
- CHAT / COST_FIRST: [12, 7, 3]
- CHAT / QUALITY_FIRST: [3, 12, 7]
- OCR / COST_FIRST: [21, 22]

## 7. Practical defaults (to be configured by admin)
Because model quality/cost/latency depend on your internal evaluation,
the gateway does NOT hardcode which vendor is "best".
Admins must configure:
- models
- prices
- policies per department and model_type

In local/dev, seed a single chain per type to allow tests to run.

## 8. Observability requirements
For each request:
- Store decision metadata:
  - policy_type
  - chain before/after filtering
  - selected model
  - fallback_used
- Persist metering in MySQL (usage_records) and index metadata into ES.
