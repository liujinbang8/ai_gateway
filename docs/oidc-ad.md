# docs/oidc-ad.md - OIDC Integration with Windows AD (V1.1)

## 1. Overview

LLM Gateway 控制面使用 OIDC 登录。
AD 作为身份源，但网关不直接对接 AD，必须通过 OIDC Provider。

典型拓扑：

`[Windows AD] -> [OIDC Provider] -> [LLM Gateway]`

可选 Provider：
- Microsoft Entra ID
- ADFS（开启 OIDC）
- Keycloak（LDAP 联邦 AD）
- 企业内部 OIDC SSO

---

## 2. V1.1 范围

### 2.1 已实现范围

- OIDC 登录
- 用户自动创建/更新
- 默认角色分配

### 2.2 明确不做

- AD 组织同步
- groups claim 自动映射角色
- LDAP/Graph 定时同步任务

部门与角色在 Admin 后台手工维护。

---

## 3. Claims 映射

必需：
- `sub` -> `users.oidc_subject`

推荐：
- `preferred_username` -> `users.username`
- `name` -> `users.display_name`
- `email` -> `users.email`

约束：
- `sub` 必须稳定且不可复用

---

## 4. Spring Boot WebFlux 配置

示例键：
- `spring.security.oauth2.client.provider.oidc.issuer-uri`
- `spring.security.oauth2.client.registration.oidc.client-id`
- `spring.security.oauth2.client.registration.oidc.client-secret`
- scope：`openid profile email`

---

## 5. 安全链路

1. Admin：`/admin/**`
- OIDC OAuth2 Login
- Session-based

2. Data Plane：`/openai/**`、`/claude/**`
- API Key
- Stateless

要求：
- Admin 不接受 API Key
- Data Plane 不要求 OIDC 登录

---

## 6. 登录流程

1. 用户访问 `/admin`
2. 重定向到 OIDC Provider
3. 登录成功回调网关
4. 解析 claims 并 upsert user
5. 分配默认角色
6. 建立会话并进入后台

---

## 7. 管理页面建议

`/admin/settings/oidc` 仅展示：
- issuer
- client_id（不展示 secret）
- login enabled
- groups claim 是否存在（状态展示）

说明：
- V1.1 为“登录接入”，非“组织同步”。

