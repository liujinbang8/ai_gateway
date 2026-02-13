# docs/observability-sre.md - Observability & SRE Guide (V1.1)

## 1. 目标

为网关提供可观测运维闭环：
- SLI/SLO 定义
- 告警规则
- 指标字典
- Tracing 规范
- 运维处置建议

---

## 2. SLI / SLO

### 2.1 数据面请求可用性（SLI）
- SLI: `successful_requests / total_requests`（剔除调用方 4xx 参数错误）
- SLO: 月度 >= 99.9%

### 2.2 数据面延迟（SLI）
- SLI: P95 / P99 `gateway_request_latency_ms`
- SLO:
  - CHAT: P95 <= 3s
  - EMBEDDING/RERANK: P95 <= 1.5s
  - OCR/VL: P95 <= 8s

### 2.3 异步任务完成率（SLI）
- SLI: `succeeded_jobs / total_jobs`
- SLO: 周度 >= 99.5%

### 2.4 成本计量及时性（SLI）
- SLI: 请求完成后 5 分钟内落账比例
- SLO: >= 99.99%

---

## 3. 告警规则（建议）

### 3.1 P1 告警
- 网关 5 分钟错误率 > 5%
- 核心路由模型全不可用（NO_MODEL_AVAILABLE 激增）
- 数据面可用性 30 分钟窗口 < 99.0%

### 3.2 P2 告警
- P95 延迟连续 15 分钟超 SLO
- Vendor 失败率 > 10% 且持续 10 分钟
- Redis Stream lag > 5,000 持续 10 分钟
- ES 写入失败率 > 2% 持续 10 分钟

### 3.3 P3 告警
- 配额拒绝率异常上升
- 安全阻断（BLOCK）事件较基线翻倍
- 成本突增（单日 > 最近 7 日均值 2 倍）

---

## 4. 指标字典（Prometheus 建议命名）

### 4.1 网关请求
- `llmgw_requests_total{base_path,endpoint,model_type,status}`
- `llmgw_request_latency_ms_bucket{endpoint,model_type}`
- `llmgw_vendor_latency_ms_bucket{vendor,model}`
- `llmgw_vendor_errors_total{vendor,code}`

### 4.2 鉴权与配额
- `llmgw_auth_failures_total{reason}`
- `llmgw_quota_rejections_total{scope_type}`

### 4.3 路由与降级
- `llmgw_fallback_total{model_type,vendor}`
- `llmgw_no_model_available_total{model_type}`

### 4.4 异步任务
- `llmgw_jobs_total{job_type,status}`
- `llmgw_job_latency_ms_bucket{job_type}`
- `llmgw_redis_stream_lag{stream,group}`

### 4.5 日志与计量
- `llmgw_es_index_failures_total{index}`
- `llmgw_usage_records_written_total{status}`
- `llmgw_cost_cny_total{vendor,model_type}`

### 4.6 安全治理
- `llmgw_security_events_total{rule_type,action,severity}`
- `llmgw_prompt_injection_score_bucket{model_type}`
- `llmgw_sensitive_word_hits_total{model_type,severity}`

---

## 5. Tracing 规范

### 5.1 Header 规范
- 必须：`x-request-id`
- 建议：W3C `traceparent`、`tracestate`
- 下游透传：对 vendor 透传 `x-request-id`（best effort）

### 5.2 Span 拆分建议
- `gateway.request`（入口总 span）
- `auth.validate_key`
- `security.guardrail`（敏感词 + 注入检测）
- `routing.select_model`
- `vendor.call`
- `metering.persist`
- `es.index`
- `async.enqueue` / `async.consume` / `async.execute`

### 5.3 Span 属性建议
- `request.id`
- `subject.type` / `subject.id`
- `dept.id`
- `model.type` / `model.id` / `vendor`
- `policy.type`
- `fallback.used`
- `security.action` / `security.rule_type`
- `error.code`

---

## 6. Dashboard 推荐

最少四块：
1. 稳定性：QPS、成功率、P95/P99、错误率
2. 成本：tokens、cost、Top 用户-模型、Top 组织-模型
3. 异步：队列长度、消费速率、失败重试
4. 安全：拦截数、告警趋势、命中规则分布

---

## 7. 运维处置建议（Runbook）

### 7.1 Vendor 故障
1. 查看 `vendor_errors_total` 与 `fallback_total`
2. 临时切换部门策略到备用模型链
3. 记录变更审计并观察恢复

### 7.2 队列积压
1. 检查 `redis_stream_lag`
2. 扩容 worker
3. 排查单任务超时与外部依赖

### 7.3 安全事件突增
1. 查看 `security/incidents`
2. 按规则类型定位（敏感词/注入/黑白名单）
3. 临时提高阻断策略并通知业务负责人

