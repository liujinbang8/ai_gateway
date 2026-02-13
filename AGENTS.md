# AGENTS.md

## Tech Stack
- Java 21
- Spring Boot 3.x + WebFlux (for streaming)
- MySQL 8.x
- Redis Streams (async jobs)
- MinIO (file storage)
- Elasticsearch (metadata required; raw content optional + desensitized)
- Build: Maven
- Auth: OIDC login (Windows AD-backed)
- HTTP client: Spring WebClient (direct HTTPS to vendors)

## Project Structure
- com.company.llmgw
  - dataplane (OpenAI/Claude compatible endpoints)
  - admin (RBAC, models, keys, reports)
  - auth (OIDC, API-key auth, subject resolution)
  - routing (policy engine)
  - metering (usage/cost/quota)
  - logging (ES indexing, desensitization)
  - async (Redis stream producer/consumer)
  - storage (MinIO)
  - vendor (adapters: openai, anthropic, gemini, aliyun, glm...)

## Commands
- Build + test: `mvn -q test`
- Run (local): `mvn spring-boot:run -Dspring-boot.run.profiles=local`
- Infra: `docker compose up -d mysql redis elasticsearch minio`

## Required Endpoints
- Health: `/healthz`, `/readyz`
- OpenAI-compatible base: `/openai/v1`
- Claude-compatible base: `/claude/v1`
- Admin base: `/admin`

## Security Rules
- Never store plaintext API keys; store SHA-256(key + server_salt) only.
- Vendor credentials are encrypted at rest; prefer K8s Secret injection.
- ES raw prompt/response logging is OFF by default; when ON must desensitize.
