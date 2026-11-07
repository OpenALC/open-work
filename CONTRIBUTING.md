# 贡献指南

感谢你考虑为 OpenWork 贡献代码。本文说明参与方式、开发环境、提交规范与审查要求。

---

## 一、开始之前

1. 阅读 [README.md](README.md) 了解项目定位与边界
2. 阅读 [AGENTS.md](AGENTS.md) 了解技术基线与模块边界（人类贡献者同样适用）
3. 阅读 [docs/development/roadmap.md](docs/development/roadmap.md) 了解当前里程碑
4. 在 Issue 中确认你要做的事没有被别人认领

**项目边界很重要：** OpenWork 不内置 ERP、CRM、MES、WMS、财务、完整 HR 薪酬、复杂项目管理、文档协作套件。这类需求请走应用 / 连接器 / 开放 API，不要提交为核心模块。

---

## 二、可以贡献什么

| 类型 | 入口 |
|---|---|
| 缺陷报告 | [Bug issue 模板](.github/ISSUE_TEMPLATE/bug_report.md) |
| 功能建议 | [Feature issue 模板](.github/ISSUE_TEMPLATE/feature_request.md)，先说清业务场景与现有能力为何不够 |
| 代码贡献 | 见下方流程；优先认领带 `good first issue` / `help wanted` 的 Issue |
| 文档 | 直接提 PR |
| 数据库适配（MariaDB / PostgreSQL） | 先在 Issue 中讨论，属于社区适配方向，不改变官方 MySQL 基线 |
| 连接器 | 走 Connector SDK，独立进程，不进入核心仓库 |
| 安全漏洞 | **不要公开提 issue**，见 [SECURITY.md](SECURITY.md) |

---

## 三、开发环境

### 3.1 依赖

| 工具 | 版本 |
|---|---|
| Go | 1.25+ |
| Node.js | 24 LTS |
| pnpm | 10+ |
| Flutter | 3.35+（仅客户端开发需要） |
| Docker + Compose | 最新稳定版 |
| golangci-lint | 见 `.golangci.yml` |
| golang-migrate | 见 Makefile |
| sqlc | 见 `sqlc.yaml` |

### 3.2 初始化

```bash
git clone https://github.com/OpenALC/open-work.git
cd open-work
make bootstrap
make dev-up
```

`make bootstrap` 会：安装工具链依赖、拉取 Go 与 pnpm 依赖、生成 sqlc 代码与 OpenAPI 客户端、从 `.env.example` 生成 `.env`。

### 3.3 常用命令

```bash
make dev-up            # 起本地服务栈
make dev-down          # 停
make logs              # 跟日志
make test              # 单元测试
make test-integration  # 集成测试（需要本地 MySQL/Redis，dev-up 已提供）
make ci                # 与 CI 等价的全部门禁
make migrate-up        # 执行迁移
make migrate-create name=add_xxx
make sqlc              # 重新生成数据访问代码
make openapi-gen       # 重新生成契约客户端
```

---

## 四、分支与提交

采用 **Trunk-Based Development**。

### 4.1 分支命名

```text
feat/<short-slug>
fix/<short-slug>
refactor/<short-slug>
docs/<short-slug>
chore/<short-slug>
test/<short-slug>
```

分支生命周期尽量短（目标 ≤ 3 天），从 `main` 切出，合回 `main`。不要长期维护个人分支。

### 4.2 提交信息

遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)：

```text
<type>(<scope>): <subject>

<body>

<footer>
```

| type | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `refactor` | 不改变行为的重构 |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `docs` | 文档 |
| `ci` | CI 与构建 |
| `chore` | 杂项、依赖升级 |
| `build` | 构建系统 |
| `revert` | 回滚 |

常用 scope：`iam` `organization` `authorization` `im` `workflow` `attendance` `announcement` `bot` `platform` `connector` `web` `flutter` `realtime` `worker` `db` `api` `security`。

示例：

```text
feat(im): support department groups with ancestor dedup

fix(auth): prevent tenant data leakage on cross-tenant lookup

test(attendance): cover overnight shift edge cases

ci: cache pnpm store across web jobs
```

**破坏性变更**在 footer 中标注：

```text
feat(api)!: change message cursor format

BREAKING CHANGE: /api/v1/conversations/{id}/messages 游标由整数改为不透明字符串，
客户端需升级到 ≥ 1.3.0。
```

### 4.3 提交粒度

- 一个提交只做一件逻辑上完整的事
- 提交必须可编译、测试可通过
- 不要提交 `.env`、密钥、本地配置、IDE 配置
- 生成代码与源文件在同一个提交中

---

## 五、提交 PR

### 5.1 PR 要求

- 标题同 Conventional Commits
- 说明：目标、变更面、验证方式、风险与回滚、需人工决策事项
- 关联 Issue（`Closes #123`）
- 用户可见变更已更新 `CHANGELOG.md` 的 `Unreleased`
- 数据库变更包含 migration + sqlc 生成结果
- API 变更更新 `docs/api/openapi.yaml`
- 涉及权限的变更登记权限码
- 单一 PR 变更 ≤ 1500 行（不含生成与测试数据文件）

### 5.2 合并方式

只使用 **Squash Merge**。合并后的提交信息取 PR 标题 + 正文，必须保持 Conventional Commits 格式。

### 5.3 合并前必须满足

- 全部必需检查通过（见 [docs/development/ci.md](docs/development/ci.md) §八）
- 至少 1 个 approving review
- 分支已与 `main` 同步
- 无未解决的 blocking 评论

---

## 六、代码规范

### 6.1 Go

分层：

```text
handler      HTTP 请求与响应，不写业务规则
application  用例编排与事务边界
domain       业务规则与不变量，不依赖框架
repository   数据持久化，参数化 SQL
infrastructure 外部依赖适配
```

必须：

- 外部 I/O 一律带 `context` 与超时
- 错误统一包装并上抛，不吞掉关键错误
- 结构化日志（`slog`），字段脱敏
- 错误码集中定义
- 并发代码说明所有权与生命周期

禁止：

- 领域层 import `gin` / `sql`
- 请求路径使用 `context.Background()`
- 字符串拼 SQL
- 循环里逐条查询（N+1）
- 无界列表接口

### 6.2 TypeScript / Vue

- `<script setup lang="ts">`，禁止 `any`（确需时写注释说明）
- 组件一个文件一个组件，容器与展示分离
- 状态用 Pinia，按模块划分 store
- 所有用户输入在服务端再次校验
- 客户端权限判断只用于显示，不当作授权

### 6.3 Dart / Flutter

- `flutter analyze --fatal-infos` 零告警
- 原生能力通过适配器接口访问，业务代码不直接调 platform channel
- 平台差异集中在一个适配层

### 6.4 数据库

- InnoDB、`utf8mb4`、`snake_case`、`BIGINT` 主键
- 时间存 UTC，字段精度显式声明
- 多租户表必须有 `tenant_id` 且带索引，唯一约束包含 `tenant_id`
- 迁移只增不改；已合并的迁移禁止编辑
- 大表 DDL 使用 online DDL 或分批回填

### 6.5 安全底线

以下在审查中直接判定为阻断项：

- 未参数化 SQL
- 请求路径缺租户作用域
- 端点缺服务端权限校验
- 日志输出敏感字段原文
- 关闭 TLS 校验
- 硬编码凭据
- WebView Bridge 未校验来源与 Scope

---

## 七、测试要求

| 类型 | 要求 |
|---|---|
| 单元测试 | 新增与修改逻辑覆盖率 ≥ 70%；纯函数与状态机优先 |
| 集成测试 | 涉及事务、迁移、Outbox、并发、跨模块的必须写；使用 CI 服务容器提供的真实 MySQL + Redis |
| 契约测试 | 新增或修改端点必须覆盖 |
| 越权测试 | 新增端点必须有跨租户与无权限用例 |
| E2E | 关键用户路径（登录、建部门、发消息、提审批、打卡） |

测试质量红线：

- 不得跳过测试、降低断言来通过 CI
- 不得用 mock 替换被测逻辑本身
- 断言必须验证可观察行为，而非实现细节

---

## 八、审查流程

详见 [docs/development/review.md](docs/development/review.md)。简要：

1. CI 自动门禁
2. 机器人检查（文档同步、CHANGELOG、迁移不可变、权限登记）
3. 自动审查 agent 给出阻断项与建议项，以 `file:line` 定位
4. 人工抽检与里程碑集中审查

对审查意见有异议时，以 ADR 为准；ADR 未覆盖时说明理由并请维护者裁决。不要沉默地忽略审查意见。

---

## 九、文档要求

代码变更伴随文档：

| 变更 | 需要更新 |
|---|---|
| 新增模块 | `internal/<module>/README.md` |
| 新增端点 | `docs/api/openapi.yaml` |
| 架构决策 | `docs/adr/` 新增 ADR |
| 用户可见变更 | `CHANGELOG.md` |
| 新增配置项 | 部署文档 + `.env.example` |
| 新增权限码 | 权限目录 |

ADR 模板见 [docs/adr/README.md](docs/adr/README.md)。决策一旦被后续决策推翻，不删除旧 ADR，新增一条标注 `Supersedes`。

---

## 十、许可证

贡献即表示你同意你的贡献以 [Apache License 2.0](LICENSE) 授权。提交前请确认你有权提交该代码（无第三方专有代码、无冲突许可证）。禁止引入 GPL / AGPL / SSPL 等不兼容许可证的依赖到 `cmd/`、`internal/`、`apps/`、`packages/`。

---

## 十一、行为准则

参与本项目即表示同意遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。
