# docs/authz.md - Authentication & Authorization (OIDC + API Keys)

## 1. Goals

- Admin 控制面使用 OIDC 登录（AD-backed）。
- 数据面调用使用 API Key。
- 授权粒度到模型（model-level）。
- RBAC 同时覆盖：admin 菜单/按钮权限 + 数据面模型权限。
- v1.1 明确：不做 AD 组织/群组自动同步。

---

## 2. Subjects

请求主体（Subject）：
- USER
- APP

每个数据面请求需解析：
- `api_key_id`
- `subject_type + subject_id`
- `dept_id`

---

## 3. 数据面认证

### 3.1 协议与 Header

- OpenAI base：`/openai/v1`
  - `Authorization: Bearer <api_key>`
- Claude base：`/claude/v1`
  - `x-api-key: <api_key>`

### 3.2 API Key 存储与校验

- 不得存储明文 key
- `key_hash = SHA-256(api_key + SERVER_SALT)`

校验条件：
- key 存在且未吊销
- 未过期
- owner 处于 active

错误语义：
- 无效/过期/吊销 -> 401
- owner inactive -> 403

### 3.3 请求标识

- 如无 `x-request-id`，网关生成
- 在响应头返回 `x-request-id`
- vendor 调用 best-effort 透传

---

## 4. 控制面认证（OIDC）

### 4.1 约束

- AD 本身不直接提供 OIDC，需前置 IdP（Entra/ADFS/Keycloak/企业SSO）
- 网关仅对接 OIDC Provider

### 4.2 登录映射

登录成功后：
- 读取 `sub` 作为 `users.oidc_subject`
- 写入 username/display_name/email（若有）
- 更新 last_login_at

### 4.3 v1.1 范围

- 支持 OIDC 登录
- 支持默认角色分配
- 不做 groups claim 自动映射
- 不做组织信息自动同步

部门与角色由管理员在后台维护。

---

## 5. 授权模型

### 5.1 角色来源

v1.1：
- 仅来自 `subject_roles`（手工维护）

### 5.2 模型授权计算

- `AllowedModelsByRole = UNION(role_model_permissions)`
- `KeyScopedModels = API key 可选收敛集`
- `EffectiveModels = AllowedModelsByRole ∩ KeyScopedModels(若存在)`

判定：
- 请求指定模型：必须属于 `EffectiveModels`
- 未指定模型：路由在 `EffectiveModels` 中选择

错误：
- 403 `MODEL_FORBIDDEN`
- 403 `NO_MODEL_AVAILABLE`

### 5.3 Admin 权限

典型权限：
- `admin:models:read/write`
- `admin:keys:read/write`
- `admin:rbac:manage`
- `admin:reports:read`
- `admin:security:read/write`

---

## 6. 安全链路隔离

必须存在两条安全链：

1. Admin：`/admin/**`（OIDC session）
2. Data Plane：`/openai/**`、`/claude/**`（API Key）

要求：
- Admin 不接受 API Key
- Data Plane 不依赖 OIDC session

---

## 7. 审计

管理操作必须写 `admin_audit_logs`：
- 模型/路由/RBAC/API Key 变更
- 安全治理策略变更（敏感词、黑白名单、注入策略）

