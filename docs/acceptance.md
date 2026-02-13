# docs/acceptance.md - E2E Acceptance (V1.1)

## Prerequisites

- Gateway running at `http://localhost:8080`
- Environment:
  - `OPENAI_KEY`: valid gateway key for `/openai/v1`
  - `CLAUDE_KEY`: valid gateway key for `/claude/v1`
- At least one model configured and authorized for each model type.

---

## 1) Health

```bash
curl -sS http://localhost:8080/healthz
curl -sS http://localhost:8080/readyz
```

## 2) OpenAI sync contracts

```bash
curl -sS -H "Authorization: Bearer $OPENAI_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"hi"}]}' \
  http://localhost:8080/openai/v1/chat/completions

curl -sS -H "Authorization: Bearer $OPENAI_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"input":"hello"}' \
  http://localhost:8080/openai/v1/embeddings

curl -sS -H "Authorization: Bearer $OPENAI_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"input":"what is gateway","documents":["doc1","doc2"]}' \
  http://localhost:8080/openai/v1/rerank
```

## 3) Claude sync contracts

```bash
curl -sS -H "x-api-key: $CLAUDE_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"max_tokens":128,"messages":[{"role":"user","content":"hi"}]}' \
  http://localhost:8080/claude/v1/messages

curl -sS -H "x-api-key: $CLAUDE_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"query":"hello","documents":["doc1","doc2"]}' \
  http://localhost:8080/claude/v1/rerank
```

## 4) Unified async jobs

```bash
curl -sS -H "Authorization: Bearer $OPENAI_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"job_type":"RERANK","input":{"query":"test","documents":["a","b"]}}' \
  http://localhost:8080/openai/v1/jobs
```

## 5) Admin reports granularity

验证 `/admin/reports/cost` 支持：
- `period=WEEK|MONTH|QUARTER`
- `group_by=USER_MODEL|DEPT_MODEL`

