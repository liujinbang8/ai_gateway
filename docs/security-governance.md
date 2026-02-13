# docs/security-governance.md - Security Governance (V1.1)

## 1. 目标与范围

V1.1 安全治理覆盖：
- 内容安全（Content Safety）
- 提示词注入检测（Prompt Injection Detection）
- 敏感词管理（支持用户/组织白名单豁免）
- 黑白名单（用户、组织、应用、IP）
- 审计留痕与安全报表导出

默认策略：
- 检测开启（DETECT）
- 高风险阻断（BLOCK）
- 事件全量记录到安全事件表与审计日志

---

## 2. 安全处理链路（数据面）

请求进入网关后的执行顺序：
1. 鉴权（API Key / OIDC Session）
2. 黑白名单判定（ALLOW/BLOCK）
3. 提示词注入检测（risk_score）
4. 敏感词规则匹配（词库 + 正则）
5. 内容安全规则（分类标签/风险等级）
6. 路由与模型调用
7. 记录安全事件（若命中）

动作策略：
- `ALLOW`：继续请求
- `WARN`：继续请求 + 记录安全事件
- `BLOCK`：拒绝请求（建议 403/422，保留 request_id）

---

## 3. 敏感词管理

### 3.1 规则模型

每条规则包含：
- `phrase`：敏感词/模式
- `model_type`：CHAT/EMBEDDING/RERANK/VL/OCR
- `severity`：LOW/MEDIUM/HIGH
- `action`：WARN/BLOCK
- `scope_type`：GLOBAL/DEPT/USER
- `scope_id`：当 scope 为 DEPT/USER 时必填

### 3.2 白名单豁免

白名单可配置在：
- 用户级
- 组织（部门）级
- 应用级

豁免规则：
- 命中白名单后，对应敏感词策略可降级为 WARN 或跳过（可配置）
- 所有豁免行为仍需记录安全事件（action=ALLOW, reason=ALLOWLIST_BYPASS）

### 3.3 管理接口

- `GET/POST /admin/security/sensitive-words`
- `PATCH/DELETE /admin/security/sensitive-words/{id}`

---

## 4. 黑白名单管理

支持主体：
- USER
- DEPT
- APP
- IP（含 CIDR）

规则类型：
- `ALLOW`：优先通过
- `BLOCK`：直接拒绝

建议优先级：
- 显式 BLOCK > 显式 ALLOW > 默认策略

管理接口：
- `GET/POST /admin/security/access-lists`
- `PATCH/DELETE /admin/security/access-lists/{id}`

---

## 5. 提示词注入与内容安全策略

统一策略对象：
- `mode`: OFF / DETECT / BLOCK
- `score_threshold`: 注入风险分阈值（0~1）
- `content_safety_enabled`
- `sensitive_word_enabled`
- `allowlist_enabled`
- `blocklist_enabled`
- `max_risk_level`: LOW/MEDIUM/HIGH

管理接口：
- `GET/PUT /admin/security/prompt-injection/policy`

建议默认：
- `mode=DETECT`
- `score_threshold=0.7`
- `max_risk_level=HIGH`

---

## 6. 安全事件、审计与报表（含导出）

### 6.1 安全事件记录

每次命中至少记录：
- `timestamp`
- `request_id`
- `rule_type`（SENSITIVE_WORD/PROMPT_INJECTION/ACCESS_LIST）
- `severity`
- `action`（ALLOW/WARN/BLOCK）
- `subject`、`dept`、`model`、`model_type`
- `detail_json`

接口：
- `GET /admin/security/incidents`

### 6.2 审计留痕

以下操作必须写 `admin_audit_logs`：
- 新增/修改/禁用敏感词规则
- 新增/修改/禁用黑白名单
- 修改注入检测策略

### 6.3 安全报表导出

支持按 周/月/季度 聚合导出，维度包含：
- rule_type
- action
- model_type
- dept
- user

接口：
- `GET /admin/reports/security`

---

## 7. 数据模型建议（V1.1）

建议新增表：
- `sensitive_words`
- `access_list_entries`
- `prompt_injection_policies`
- `security_incidents`

与计量账本关联键：
- `request_id`
- `job_id`

