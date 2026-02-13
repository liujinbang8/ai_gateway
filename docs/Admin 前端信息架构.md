# Admin 前端信息架构（IA，V1.1）

## 顶部全局

- 右上角：当前用户 / 部门 / 角色、退出登录
- 全局搜索（可选 V1.1+）：request_id / job_id / api_key_id / username
- 环境标识（dev/test/prod）角标

## 左侧菜单（V1.1 推荐）

1. 概览仪表盘
2. 模型与路由
   - 模型列表
   - 厂商凭据
   - 路由策略
3. 访问与权限
   - API Key 管理
   - 用户管理
   - 应用管理
   - 角色管理
   - 权限资源
   - 模型授权
4. 配额与成本
   - 配额管理
   - 用量统计
   - 成本报表
5. 安全治理
   - 敏感词管理
   - 黑白名单
   - 注入检测与内容安全策略
   - 安全事件
   - 安全报表
6. 运行与审计
   - 请求日志（ES）
   - 异步任务（Jobs）
   - 管理审计（Admin Audit）
7. 系统设置
   - OIDC 连接状态（仅登录，不做组织同步）
   - ES 原文开关与脱敏规则
   - 系统参数

---

# 页面清单与设计

## 1）概览仪表盘

**路径**：`/dashboard`

核心卡片：
- 请求数、成功率、P95 延迟
- tokens、总费用
- 安全拦截数（WARN/BLOCK）
- 异步队列积压

权限：
- `admin:dashboard:read`

---

## 2）模型与路由

### 2.1 模型列表

**路径**：`/models`

字段：
- name / vendor / model_type / vendor_model_id
- enabled / input_price / output_price / timeout

类型覆盖：
- CHAT / EMBEDDING / RERANK / VL / OCR

操作：
- 新建、编辑、启停、复制、详情

权限：
- `admin:models:read`
- `admin:models:write`

### 2.2 路由策略

**路径**：`/routing`

能力：
- 按部门 + model_type 管理策略
- 成本/质量/延迟三策略
- model chain 拖拽排序
- 校验禁用模型/无权限模型

权限：
- `admin:routing:read`
- `admin:routing:write`

---

## 3）访问与权限

### 3.1 API Key

**路径**：`/api-keys`

操作：
- 创建、吊销、延期、模型收敛

权限：
- `admin:keys:read`
- `admin:keys:write`

### 3.2 用户/应用

**路径**：`/users`、`/apps`

操作：
- 启停、绑定部门、分配角色

权限：
- `admin:users:read`
- `admin:users:write`
- `admin:apps:read`
- `admin:apps:write`

### 3.3 角色与模型授权

**路径**：`/roles`、`/permissions`、`/role-models`

操作：
- 角色管理
- 菜单/按钮权限
- 角色模型授权

权限：
- `admin:rbac:manage`

---

## 4）配额与成本

### 4.1 配额管理

**路径**：`/quotas`

- 用户/组织月度 token cap
- 超额拒绝

权限：
- `admin:quota:read`
- `admin:quota:write`

### 4.2 用量统计

**路径**：`/usage`

最小粒度：
- 用户-模型（USER_MODEL）
- 组织-模型（DEPT_MODEL）

周期：
- 周 / 月 / 季度

权限：
- `admin:reports:read`

### 4.3 成本报表

**路径**：`/cost`

核心能力：
- 周/月/季度成本趋势
- 用户-模型、组织-模型 Top 成本
- 导出

权限：
- `admin:reports:read`

---

## 5）安全治理

### 5.1 敏感词管理

**路径**：`/security/sensitive-words`

字段：
- phrase / model_type / severity / action / scope

作用域：
- GLOBAL / DEPT / USER

操作：
- 新增、编辑、禁用

### 5.2 黑白名单

**路径**：`/security/access-lists`

支持主体：
- USER / DEPT / APP / IP

操作：
- ALLOW/BLOCK 规则维护
- 过期时间与生效状态

### 5.3 注入检测与内容安全策略

**路径**：`/security/prompt-injection/policy`

策略：
- OFF / DETECT / BLOCK
- score threshold
- max risk level

### 5.4 安全事件

**路径**：`/security/incidents`

字段：
- timestamp / request_id / rule_type / severity / action / subject / model

### 5.5 安全报表

**路径**：`/reports/security`

周期：
- 周 / 月 / 季度

维度：
- rule_type / action / model_type / dept / user

权限建议：
- `admin:security:read`
- `admin:security:write`

---

## 6）运行与审计

### 6.1 请求日志

**路径**：`/logs/requests`

- 元数据检索
- raw 仅在开关开启且有权限时可见

权限：
- `admin:logs:read`
- `admin:logs:raw:read`

### 6.2 异步任务

**路径**：`/jobs`

job_type：
- CHAT / EMBEDDING / RERANK / VL / OCR / EMBEDDING_BATCH

权限：
- `admin:jobs:read`
- `admin:jobs:write`

### 6.3 管理审计

**路径**：`/audit`

- actor / action / resource / detail

权限：
- `admin:audit:read`

---

## 7）系统设置

### 7.1 OIDC 连接状态

**路径**：`/settings/oidc`

内容：
- issuer / client_id
- 登录状态
- groups claim 状态（展示）

说明：
- V1.1 不做组织/群组自动同步

### 7.2 日志与脱敏

**路径**：`/settings/logging`

内容：
- rawEnabled
- 脱敏规则

### 7.3 系统参数

**路径**：`/settings/system`

内容：
- 上传限制
- vendor timeout
- 默认路由策略

---

## 8）关键交互规范

高风险操作必须：
- 二次确认
- 写审计日志

高风险操作清单：
- 吊销 Key
- 更新模型凭据
- 启停模型
- 修改注入检测策略
- 修改黑白名单
- 开启 ES 原文
