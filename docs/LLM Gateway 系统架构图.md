# LLM Gateway 系统架构图文字版（V1.1）

## 1. 架构总览（分层视图）

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        企业身份层 / SSO (OIDC)                           │
│  Windows AD  ──>  OIDC Provider (Entra / ADFS / Keycloak / 内部SSO)       │
└──────────────────────────────────────────────────────────────────────────┘
                      │ (OIDC login only, no org sync in v1.1)
                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        LLM Gateway - 控制面 (Admin)                      │
│  Admin Web/UI  ──>  /admin/** (OIDC Session)                              │
│  - 模型管理 - 路由策略 - RBAC - API Key - 配额/成本 - 审计               │
│  - 安全治理(敏感词/黑白名单/注入策略) - 可观测运维设置                    │
└──────────────────────────────────────────────────────────────────────────┘
                      │ (读写 MySQL 配置；读 ES/Metrics)
                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        LLM Gateway - 数据面 (Gateway)                    │
│  业务系统/应用                                                            │
│   ├─ OpenAI SDK/Client  -> /openai/v1/** (Bearer)                        │
│   └─ Claude SDK/Client  -> /claude/v1/** (x-api-key)                     │
│                                                                          │
│  核心能力：                                                               │
│  - API Key鉴权(哈希) - 模型授权(到模型) - 部门路由策略                    │
│  - 安全治理链路(黑白名单/注入检测/敏感词/内容安全)                         │
│  - 同步/流式/异步调用 - 计量计费(usage/token/cost)                        │
│  - fallback - 脱敏日志(ES) - Tracing - 文件直传(MinIO)                   │
└──────────────────────────────────────────────────────────────────────────┘
         │                       │                       │              │
         ▼                       ▼                       ▼              ▼
┌──────────────┐       ┌────────────────┐      ┌────────────────┐  ┌──────────────┐
│    MySQL      │       │ Elasticsearch  │      │ Redis Stream    │  │    MinIO      │
│ (配置+账本)   │       │ (日志/检索)    │      │ (异步队列)      │  │ (文件存储)    │
└──────────────┘       └────────────────┘      └────────────────┘  └──────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        可观测与告警层                                    │
│  Prometheus / Alertmanager / Tracing Backend                             │
└──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        外部大模型厂商 (HTTPS直连)                         │
│  OpenAI / Anthropic / Gemini / Aliyun / GLM / ...                        │
│  - Chat / Embedding / Rerank / VL / OCR                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 关键组件说明

### 2.1 控制面（Admin）

- 入口：`/admin/**`
- 认证：OIDC（AD-backed）
- 功能：
  - 模型管理（厂商、类型、价格、超时、启用/禁用、凭据）
  - 路由策略（按部门 + model_type）
  - RBAC（用户/角色/权限/角色模型授权）
  - API Key 管理（个人/应用，过期/吊销/模型收敛）
  - 配额与成本报表
  - 安全治理（敏感词、黑白名单、注入检测策略）
  - 请求日志与安全事件检索
  - 异步任务监控
  - 管理审计

### 2.2 数据面（Gateway）

- 协议入口：
  - OpenAI 兼容：`/openai/v1/**`
  - Anthropic 兼容：`/claude/v1/**`
- 关键职责：
  1. Key 鉴权（hash + salt）
  2. Subject 解析（User/App + dept）
  3. 授权校验（角色模型 ∩ Key 模型）
  4. 安全治理判定（allow/block + 注入风险 + 敏感词）
  5. 路由决策（部门策略 + 模型链 + fallback）
  6. 厂商调用（同步/流式/异步）
  7. 计量计费落账（usage_records）
  8. 日志与审计（ES 元数据必存；原文可选且脱敏）

### 2.3 Worker（异步执行器）

- 输入：Redis Stream 消息（job_id、job_type、owner、dept、file_ids、input_json）
- job_type：`CHAT | EMBEDDING | RERANK | VL | OCR | EMBEDDING_BATCH`
- 执行：
  - 拉取 job -> RUNNING
  - 调用 vendor adapter
  - 写 result/error -> SUCCEEDED/FAILED
  - 写 ES 日志与安全事件
  - ACK 消息

---

## 3. 关键链路

### 3.1 同步请求（以 Chat 为例）

```
Client -> POST /openai/v1/chat/completions
 -> API Key hash lookup
 -> Resolve subject + dept
 -> RBAC & model authorization
 -> Security governance (access-list / injection / sensitive words)
 -> Routing select model
 -> Vendor call
 -> Collect usage/tokens/cost
 -> Write MySQL usage_records
 -> Index ES metadata (+ security incident if any)
 -> Return response
```

### 3.2 多模态 VL 同步请求

```
OpenAI: POST /openai/v1/responses
Claude: POST /claude/v1/messages
 -> same authz + security + routing
 -> vendor multimodal call
 -> metering + ES + trace
```

### 3.3 异步任务

```
Client -> POST /openai/v1/jobs or /claude/v1/jobs
 -> create MySQL job(PENDING)
 -> publish Redis stream
 -> return job_id
Worker -> consume -> execute -> persist -> finalize
Client -> GET /.../jobs/{job_id}
```

---

## 4. 数据存储职责

### MySQL（权威配置与账本）

- 身份与权限：users/apps/roles/permissions/subject_roles
- 模型与路由：models/model_credentials/dept_routing_policies
- 计量计费：quotas/usage_records
- 安全治理：sensitive_words/access_lists/prompt_policies/security_incidents
- 运行与审计：jobs/files/admin_audit_logs

### Elasticsearch（检索与分析）

- 请求元数据（必存）
- 原文 prompt/response（可选，默认关，开启即脱敏）
- 安全事件检索
- 管理报表快速聚合

### Redis Stream（异步解耦）

- 承载异步任务流转
- 幂等以 MySQL job 状态为准

### MinIO（对象存储）

- OCR/VL 文件
- 通过 file_id 关联审计链路

---

## 5. 安全边界

- Admin 面：OIDC 登录 + RBAC
- Data 面：API Key 鉴权 + 模型授权 + 安全治理拦截
- 厂商凭据：加密存储，不回显明文
- 原文日志：默认关闭，开启需审计
- 黑白名单：命中 BLOCK 即拒绝
- 配额超额：429 拒绝

---

## 6. 可观测与运维

- SLO：可用性、延迟、异步成功率、落账及时性
- 告警：错误率、延迟、队列积压、安全事件突增
- 指标：Prometheus 指标字典统一命名
- Tracing：`x-request-id` + `traceparent` 透传

详见：`docs/observability-sre.md`

---

## 7. OIDC 说明（V1.1）

- 仅做登录鉴权与用户基础信息映射
- 暂不做 AD 组织/群组自动同步
- 部门与角色在管理后台手工维护

