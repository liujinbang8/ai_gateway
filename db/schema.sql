-- db/schema.sql
-- LLM Gateway v1 minimal schema (MySQL 8.x)

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- -----------------------------
-- Basic org / identity
-- -----------------------------
CREATE TABLE IF NOT EXISTS departments (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  name          VARCHAR(128) NOT NULL,
  code          VARCHAR(64)  NOT NULL UNIQUE,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  -- OIDC subject / unique user key from IdP (preferred_username/email/subject)
  oidc_subject  VARCHAR(256) NOT NULL UNIQUE,
  username      VARCHAR(128) NOT NULL,
  display_name  VARCHAR(128) NULL,
  email         VARCHAR(256) NULL,
  dept_id       BIGINT NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  last_login_at TIMESTAMP NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_dept FOREIGN KEY (dept_id) REFERENCES departments(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS apps (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  name          VARCHAR(128) NOT NULL,
  owner_user_id BIGINT NULL,
  dept_id       BIGINT NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_apps_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_apps_dept  FOREIGN KEY (dept_id) REFERENCES departments(id)
) ENGINE=InnoDB;

-- -----------------------------
-- RBAC (minimal but extensible)
-- -----------------------------
CREATE TABLE IF NOT EXISTS roles (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  name        VARCHAR(64) NOT NULL UNIQUE,
  is_default  TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS permissions (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  code        VARCHAR(128) NOT NULL UNIQUE,
  description VARCHAR(256) NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id       BIGINT NOT NULL,
  permission_id BIGINT NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles(id),
  CONSTRAINT fk_rp_perm FOREIGN KEY (permission_id) REFERENCES permissions(id)
) ENGINE=InnoDB;

-- subject roles: user or app can have roles (v1: mostly user roles)
CREATE TABLE IF NOT EXISTS subject_roles (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  subject_type ENUM('USER','APP') NOT NULL,
  subject_id   BIGINT NOT NULL,
  role_id      BIGINT NOT NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_subject_role (subject_type, subject_id, role_id),
  CONSTRAINT fk_sr_role FOREIGN KEY (role_id) REFERENCES roles(id)
) ENGINE=InnoDB;

-- AD groups mapping (optional v1; keep table for future)
CREATE TABLE IF NOT EXISTS ad_groups (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  external_id VARCHAR(256) NOT NULL UNIQUE,
  name        VARCHAR(256) NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ad_group_role_mappings (
  ad_group_id BIGINT NOT NULL,
  role_id     BIGINT NOT NULL,
  PRIMARY KEY (ad_group_id, role_id),
  CONSTRAINT fk_agrm_group FOREIGN KEY (ad_group_id) REFERENCES ad_groups(id),
  CONSTRAINT fk_agrm_role  FOREIGN KEY (role_id) REFERENCES roles(id)
) ENGINE=InnoDB;

-- -----------------------------
-- Model management
-- -----------------------------
CREATE TABLE IF NOT EXISTS models (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  name            VARCHAR(128) NOT NULL UNIQUE,            -- internal model name
  vendor          VARCHAR(64)  NOT NULL,                   -- openai/anthropic/gemini/aliyun/glm/...
  model_type      ENUM('CHAT','EMBEDDING','RERANK','VL','OCR') NOT NULL,
  vendor_model_id VARCHAR(256) NOT NULL,                   -- actual vendor model identifier
  enabled         TINYINT(1) NOT NULL DEFAULT 1,

  -- pricing (internal settlement)
  currency        VARCHAR(16) NOT NULL DEFAULT 'CNY',
  input_price     DECIMAL(18,8) NOT NULL DEFAULT 0,        -- price per 1k tokens (or per token as you define; document it)
  output_price    DECIMAL(18,8) NOT NULL DEFAULT 0,

  max_context     INT NULL,
  timeout_ms      INT NOT NULL DEFAULT 60000,

  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Each model has its own credential set (encrypted at app-layer)
CREATE TABLE IF NOT EXISTS model_credentials (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  model_id     BIGINT NOT NULL UNIQUE,
  credential_type ENUM('API_KEY','AKSK','OAUTH','CUSTOM') NOT NULL DEFAULT 'API_KEY',
  enc_payload  MEDIUMTEXT NOT NULL,  -- encrypted JSON string
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_mc_model FOREIGN KEY (model_id) REFERENCES models(id)
) ENGINE=InnoDB;

-- -----------------------------
-- API Keys (user/app)
-- -----------------------------
CREATE TABLE IF NOT EXISTS api_keys (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  name          VARCHAR(128) NOT NULL,
  key_hash      CHAR(64) NOT NULL UNIQUE,     -- SHA-256 hex
  owner_type    ENUM('USER','APP') NOT NULL,
  owner_id      BIGINT NOT NULL,
  dept_id       BIGINT NOT NULL,

  -- optional: restrict this key to specific models (JSON array of model names or ids)
  scoped_models JSON NULL,

  expires_at    TIMESTAMP NULL,
  revoked_at    TIMESTAMP NULL,

  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_api_keys_owner (owner_type, owner_id),
  INDEX idx_api_keys_dept (dept_id),
  CONSTRAINT fk_api_keys_dept FOREIGN KEY (dept_id) REFERENCES departments(id)
) ENGINE=InnoDB;

-- Key-level additional model allow-list (normalized alternative to JSON; optional for v1)
CREATE TABLE IF NOT EXISTS api_key_models (
  api_key_id BIGINT NOT NULL,
  model_id   BIGINT NOT NULL,
  PRIMARY KEY (api_key_id, model_id),
  CONSTRAINT fk_akm_key   FOREIGN KEY (api_key_id) REFERENCES api_keys(id),
  CONSTRAINT fk_akm_model FOREIGN KEY (model_id) REFERENCES models(id)
) ENGINE=InnoDB;

-- Model permissions per role (model-level authorization)
CREATE TABLE IF NOT EXISTS role_model_permissions (
  role_id  BIGINT NOT NULL,
  model_id BIGINT NOT NULL,
  PRIMARY KEY (role_id, model_id),
  CONSTRAINT fk_rmp_role  FOREIGN KEY (role_id) REFERENCES roles(id),
  CONSTRAINT fk_rmp_model FOREIGN KEY (model_id) REFERENCES models(id)
) ENGINE=InnoDB;

-- -----------------------------
-- Routing policy (department default)
-- -----------------------------
CREATE TABLE IF NOT EXISTS dept_routing_policies (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  dept_id      BIGINT NOT NULL,
  model_type   ENUM('CHAT','EMBEDDING','RERANK','VL','OCR') NOT NULL,
  policy_type  ENUM('COST_FIRST','QUALITY_FIRST','LATENCY_FIRST') NOT NULL,
  -- ordered list of model_ids
  model_chain  JSON NOT NULL,
  enabled      TINYINT(1) NOT NULL DEFAULT 1,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_dept_type_policy (dept_id, model_type, policy_type),
  CONSTRAINT fk_drp_dept FOREIGN KEY (dept_id) REFERENCES departments(id)
) ENGINE=InnoDB;

-- -----------------------------
-- Quotas (monthly token caps)
-- 0 means unlimited (enforced in app logic)
-- -----------------------------
CREATE TABLE IF NOT EXISTS quotas (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  scope_type    ENUM('USER','DEPT') NOT NULL,
  scope_id      BIGINT NOT NULL,
  month_yyyymm  CHAR(6) NOT NULL,        -- e.g. 202602
  token_cap     BIGINT NOT NULL DEFAULT 0,
  token_used    BIGINT NOT NULL DEFAULT 0,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_quota_scope_month (scope_type, scope_id, month_yyyymm)
) ENGINE=InnoDB;

-- -----------------------------
-- Metering & auditing
-- -----------------------------
CREATE TABLE IF NOT EXISTS usage_records (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  request_id    VARCHAR(64) NOT NULL,
  base_path     ENUM('OPENAI','CLAUDE') NOT NULL,
  endpoint      VARCHAR(128) NOT NULL,

  api_key_id    BIGINT NOT NULL,
  owner_type    ENUM('USER','APP') NOT NULL,
  owner_id      BIGINT NOT NULL,
  dept_id       BIGINT NOT NULL,

  model_id      BIGINT NOT NULL,
  vendor        VARCHAR(64) NOT NULL,
  vendor_model_id VARCHAR(256) NOT NULL,

  input_tokens  BIGINT NOT NULL DEFAULT 0,
  output_tokens BIGINT NOT NULL DEFAULT 0,
  cost_cny      DECIMAL(18,8) NOT NULL DEFAULT 0,

  latency_ms    BIGINT NOT NULL DEFAULT 0,
  status        ENUM('SUCCESS','FAILED') NOT NULL,
  error_code    VARCHAR(64) NULL,

  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_usage_req (request_id),
  INDEX idx_usage_owner (owner_type, owner_id, created_at),
  INDEX idx_usage_dept (dept_id, created_at),
  INDEX idx_usage_model (model_id, created_at),
  CONSTRAINT fk_usage_key FOREIGN KEY (api_key_id) REFERENCES api_keys(id),
  CONSTRAINT fk_usage_dept FOREIGN KEY (dept_id) REFERENCES departments(id),
  CONSTRAINT fk_usage_model FOREIGN KEY (model_id) REFERENCES models(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  actor_user_id BIGINT NOT NULL,
  action       VARCHAR(128) NOT NULL,
  resource_type VARCHAR(64) NOT NULL,
  resource_id  VARCHAR(128) NULL,
  detail_json  JSON NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_actor (actor_user_id, created_at),
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- -----------------------------
-- Security governance
-- -----------------------------
CREATE TABLE IF NOT EXISTS sensitive_words (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  phrase        VARCHAR(512) NOT NULL,
  model_type    ENUM('CHAT','EMBEDDING','RERANK','VL','OCR') NOT NULL,
  severity      ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
  action        ENUM('WARN','BLOCK') NOT NULL DEFAULT 'WARN',
  scope_type    ENUM('GLOBAL','DEPT','USER') NOT NULL DEFAULT 'GLOBAL',
  scope_id      BIGINT NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_by_user_id BIGINT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_sw_lookup (model_type, scope_type, scope_id, is_active),
  CONSTRAINT fk_sw_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS access_list_entries (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  list_type     ENUM('ALLOW','BLOCK') NOT NULL,
  subject_type  ENUM('USER','DEPT','APP','IP') NOT NULL,
  subject_id    BIGINT NULL,
  subject_value VARCHAR(256) NULL, -- for IP/CIDR or external identifiers
  reason        VARCHAR(512) NULL,
  expires_at    TIMESTAMP NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_by_user_id BIGINT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_al_match (list_type, subject_type, subject_id, is_active),
  CONSTRAINT fk_al_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS prompt_injection_policies (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  mode          ENUM('OFF','DETECT','BLOCK') NOT NULL DEFAULT 'DETECT',
  score_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.7000,
  content_safety_enabled TINYINT(1) NOT NULL DEFAULT 1,
  sensitive_word_enabled TINYINT(1) NOT NULL DEFAULT 1,
  allowlist_enabled TINYINT(1) NOT NULL DEFAULT 1,
  blocklist_enabled TINYINT(1) NOT NULL DEFAULT 1,
  max_risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'HIGH',
  updated_by_user_id BIGINT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_pip_updater FOREIGN KEY (updated_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS security_incidents (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  request_id    VARCHAR(64) NULL,
  job_id        VARCHAR(64) NULL,
  rule_type     ENUM('SENSITIVE_WORD','PROMPT_INJECTION','ACCESS_LIST') NOT NULL,
  rule_id       VARCHAR(128) NULL,
  severity      ENUM('LOW','MEDIUM','HIGH') NOT NULL,
  action        ENUM('ALLOW','WARN','BLOCK') NOT NULL,
  model_type    ENUM('CHAT','EMBEDDING','RERANK','VL','OCR') NOT NULL,
  model_id      BIGINT NULL,
  owner_type    ENUM('USER','APP') NULL,
  owner_id      BIGINT NULL,
  dept_id       BIGINT NULL,
  detail_json   JSON NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_sec_time (created_at),
  INDEX idx_sec_rule (rule_type, action, severity, created_at),
  INDEX idx_sec_owner (owner_type, owner_id, created_at),
  INDEX idx_sec_dept (dept_id, created_at),
  CONSTRAINT fk_sec_model FOREIGN KEY (model_id) REFERENCES models(id),
  CONSTRAINT fk_sec_dept FOREIGN KEY (dept_id) REFERENCES departments(id)
) ENGINE=InnoDB;

-- -----------------------------
-- Files (MinIO metadata)
-- -----------------------------
CREATE TABLE IF NOT EXISTS files (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  file_name     VARCHAR(512) NOT NULL,
  content_type  VARCHAR(128) NOT NULL,
  size_bytes    BIGINT NOT NULL,
  sha256_hex    CHAR(64) NOT NULL,
  bucket        VARCHAR(128) NOT NULL,
  object_key    VARCHAR(1024) NOT NULL,
  created_by_user_id BIGINT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_files_sha (sha256_hex),
  CONSTRAINT fk_files_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- -----------------------------
-- Async jobs
-- -----------------------------
CREATE TABLE IF NOT EXISTS jobs (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  job_id        VARCHAR(64) NOT NULL UNIQUE, -- external id
  job_type      ENUM('CHAT','EMBEDDING','RERANK','VL','OCR','EMBEDDING_BATCH') NOT NULL,
  base_path     ENUM('OPENAI','CLAUDE') NOT NULL DEFAULT 'OPENAI',
  requested_model_id BIGINT NULL,
  model_type    ENUM('CHAT','EMBEDDING','RERANK','VL','OCR') NOT NULL,

  api_key_id    BIGINT NOT NULL,
  owner_type    ENUM('USER','APP') NOT NULL,
  owner_id      BIGINT NOT NULL,
  dept_id       BIGINT NOT NULL,

  file_ids      JSON NULL,     -- array of file ids for OCR/VL
  input_json    JSON NULL,     -- embedding batch inputs or misc options

  status        ENUM('PENDING','RUNNING','SUCCEEDED','FAILED','CANCELED') NOT NULL DEFAULT 'PENDING',
  attempt       INT NOT NULL DEFAULT 0,
  max_attempts  INT NOT NULL DEFAULT 3,
  error_code    VARCHAR(64) NULL,
  error_message VARCHAR(1024) NULL,

  result_json   JSON NULL,

  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_jobs_status (status, updated_at),
  INDEX idx_jobs_owner (owner_type, owner_id, created_at),

  CONSTRAINT fk_jobs_key  FOREIGN KEY (api_key_id) REFERENCES api_keys(id),
  CONSTRAINT fk_jobs_dept FOREIGN KEY (dept_id) REFERENCES departments(id),
  CONSTRAINT fk_jobs_model FOREIGN KEY (requested_model_id) REFERENCES models(id)
) ENGINE=InnoDB;

-- -----------------------------
-- Seed minimal roles (optional)
-- -----------------------------
INSERT IGNORE INTO roles (name, is_default) VALUES ('DEFAULT_USER', 1), ('ADMIN', 0);
