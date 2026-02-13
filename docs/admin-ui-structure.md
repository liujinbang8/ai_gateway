# docs/admin-ui-structure.md - LLM Gateway Admin UI Structure (V1.1)

版本：1.1  
适用范围：LLM Gateway V1.1（内部单租户）

---

## 1. 设计目标

Admin 后台能力闭环：

- 模型与路由集中配置
- 访问控制（API Key + RBAC + 模型授权）
- 配额与成本治理（支持 USER_MODEL / DEPT_MODEL + 周/月/季度）
- 安全治理（敏感词、黑白名单、注入检测、事件报表）
- 运行可观测（日志、异步任务、审计、SLO 运维视图）
- OIDC 登录（AD-backed，v1.1 不做组织自动同步）

---

## 2. 全局 UI 规范

### 2.1 全局元素
- 顶部栏：用户信息、角色、退出登录、环境角标
- 左侧菜单：权限动态渲染
- 全局搜索（可选）：request_id / job_id / api_key_id / username

### 2.2 通用筛选
- 时间范围（统计、日志、安全事件）
- 部门、用户、应用
- 模型类型、厂商、模型
- 状态（成功/失败、active/revoked、warn/block）

### 2.3 高风险操作规范（必须二次确认 + 审计）
- 吊销 API Key
- 更新模型凭据
- 开启 ES 原文
- 更新注入检测策略
- 更新黑白名单
- 更新敏感词规则

---

## 3. 菜单结构（V1.1）

### 3.1 概览
- `/dashboard`
- 指标：请求、成功率、P95、tokens、cost、安全拦截、队列积压
- 权限：`admin:dashboard:read`

### 3.2 模型与路由
- `/models`、`/models/:id`、`/routing`
- 覆盖模型类型：CHAT/EMBEDDING/RERANK/VL/OCR
- 权限：`admin:models:*`、`admin:routing:*`、`admin:credentials:write`

### 3.3 访问与权限
- `/api-keys`、`/users`、`/apps`、`/roles`、`/permissions`、`/role-models`
- 权限：`admin:keys:*`、`admin:users:*`、`admin:apps:*`、`admin:rbac:manage`

### 3.4 配额与成本
- `/quotas`
- `/usage`（period=week/month/quarter，group_by 支持 USER_MODEL/DEPT_MODEL）
- `/cost`（同上）
- 权限：`admin:quota:*`、`admin:reports:read`

### 3.5 安全治理
- `/security/sensitive-words`
- `/security/access-lists`
- `/security/prompt-injection/policy`
- `/security/incidents`
- `/reports/security`
- 权限：`admin:security:read`、`admin:security:write`

### 3.6 运行与审计
- `/logs/requests`
- `/jobs`
- `/audit`
- 权限：`admin:logs:*`、`admin:jobs:*`、`admin:audit:read`

### 3.7 系统设置
- `/settings/oidc`（仅登录状态，不含组织同步）
- `/settings/logging`
- `/settings/system`
- 权限：`admin:settings:*`

---

## 4. 重点页面说明

### 4.1 成本报表
- 维度：USER_MODEL / DEPT_MODEL / USER / DEPT / MODEL / VENDOR
- 周期：WEEK / MONTH / QUARTER
- 输出：趋势图 + Top N + 导出

### 4.2 安全事件页
- 过滤：rule_type/action/severity/model_type/dept/user
- 详情：request_id、命中规则、动作、上下文摘要

### 4.3 任务页
- job_type：CHAT / EMBEDDING / RERANK / VL / OCR / EMBEDDING_BATCH
- 操作：重试、取消、查看结果

---

## 5. 前后端契约建议

- 后端单一事实来源：`openapi/admin.yaml`
- 前端由 OpenAPI 生成 client
- 菜单与按钮显隐由 `permission_codes` 决定
