# docs/async-jobs.md - Async Jobs (Redis Streams, V1.1)

## Overview

异步任务用于长耗时或批量任务：
- CHAT
- EMBEDDING
- RERANK
- VL
- OCR
- EMBEDDING_BATCH

队列技术：Redis Streams。

---

## Redis Streams

- Stream name: `llmgw:jobs`
- Consumer group: `llmgw-workers`
- Consumer name: `<pod-name>`（每 worker 唯一）

---

## Message schema (fields)

- `job_id`: external id
- `job_type`: CHAT | EMBEDDING | RERANK | VL | OCR | EMBEDDING_BATCH
- `model_type`: CHAT | EMBEDDING | RERANK | VL | OCR
- `requested_model_id`: optional
- `base_path`: OPENAI | CLAUDE
- `api_key_id`
- `owner_type`: USER | APP
- `owner_id`
- `dept_id`
- `file_ids`: JSON array string
- `input_json`: JSON string
- `created_at`: epoch millis

---

## Job state machine (MySQL)

- PENDING -> RUNNING -> SUCCEEDED
- PENDING/RUNNING -> FAILED
- PENDING/RUNNING -> CANCELED

---

## Worker processing contract

1. `XREADGROUP` 读取消息。
2. 通过 job_id 读取 MySQL job；若已终态则 ACK 跳过。
3. 设置 RUNNING，`attempt += 1`。
4. 调用统一 vendor adapter 执行。
5. 写入 result_json。
6. 成功置 SUCCEEDED。
7. 失败处理：
   - `attempt < max_attempts` -> 重入队或回到 PENDING
   - 否则置 FAILED 并落 error_code/error_message
8. 终态后 ACK。

---

## Idempotency

- `job_id` 全局唯一。
- 重复消息必须可重放安全（以 MySQL 状态为准）。

---

## Observability

- 记录每任务 latency / attempts / failure reason。
- ES 索引 job 元数据（含 `job_id`）。
- Tracing span 至少包含：`async.consume`、`async.execute`。

