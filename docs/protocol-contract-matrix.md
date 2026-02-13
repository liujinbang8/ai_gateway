# docs/protocol-contract-matrix.md - OpenAI/Anthropic 协议契约矩阵 (V1.1)

## 1. 目标

统一定义五类能力（CHAT/EMBEDDING/RERANK/VL/OCR）的同步与异步契约，且同时支持：
- OpenAI 兼容协议（`/openai/v1`）
- Anthropic 兼容协议（`/claude/v1`）

---

## 2. OpenAI 协议

### 2.1 同步接口
- CHAT: `POST /openai/v1/chat/completions`
- EMBEDDING: `POST /openai/v1/embeddings`
- RERANK: `POST /openai/v1/rerank`
- VL: `POST /openai/v1/responses`
- OCR: `POST /openai/v1/ocr`

### 2.2 异步接口
- 统一入队: `POST /openai/v1/jobs`
- 状态查询: `GET /openai/v1/jobs/{job_id}`
- `job_type`: `CHAT | EMBEDDING | RERANK | VL | OCR | EMBEDDING_BATCH`

---

## 3. Anthropic 协议

### 3.1 同步接口
- CHAT/VL: `POST /claude/v1/messages`
- EMBEDDING: `POST /claude/v1/embeddings`（网关扩展）
- RERANK: `POST /claude/v1/rerank`（网关扩展）
- OCR: `POST /claude/v1/ocr`（网关扩展）

### 3.2 异步接口
- 统一入队: `POST /claude/v1/jobs`
- 状态查询: `GET /claude/v1/jobs/{job_id}`
- `job_type`: `CHAT | EMBEDDING | RERANK | VL | OCR | EMBEDDING_BATCH`

---

## 4. 契约对齐原则

1. 所有同步接口都支持显式 `model`，未指定时由路由策略选择。
2. 异步统一用 `jobs`，避免不同能力分裂为多套队列协议。
3. 所有结果都必须包含可追踪字段（至少 `request_id` 或 `job_id`）。
4. 鉴权头保持协议习惯：
   - OpenAI：`Authorization: Bearer <api_key>`
   - Anthropic：`x-api-key: <api_key>`

---

## 5. 管理面对应能力

- 模型类型：`CHAT/EMBEDDING/RERANK/VL/OCR`
- 路由策略：按 `model_type` 配置
- 权限控制：角色模型授权 + Key 模型收敛
- 计量计费：按请求与任务统一落账

