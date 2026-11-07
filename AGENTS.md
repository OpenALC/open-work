# AGENTS.md

> 本文件是 OpenWork 的**技术基线与 AI 开发作业手册**。任何自动化代码实施工具（含 LLM agent）在开始工作前必须完整阅读本文件与相关 ADR。
>
> 人类贡献者请同时阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。两者冲突时以本文件的技术约束为准。

---

## 一、不可协商的基线

| 项 | 值 |
|---|---|
| 许可证 | Apache-2.0 |
| 后端语言 | Go 1.25+ |
| HTTP 框架 | Gin |
| 数据访问 | sqlc + `database/sql`（禁止 ORM） |
| 数据库 | MySQL 8.4 LTS（唯一官方支持） |
| 缓存 / 在线状态 | Redis 7+ |
| 可靠事件 | MySQL Transactional Outbox |
| 实时通道 | WebSocket |
| API 契约 | OpenAPI 3.1（契约先行） |
| 前端 | Vue 3 + TypeScript + Vite + Pinia + Naive UI |
| 跨端 | Flutter |
| 迁移工具 | golang-migrate |
| 日志 | `log/slog`（结构化 JSON） |
| 可观测性 | OpenTelemetry |
| 部署 | Docker Compose |
| CI | GitHub Actions |
| 仓库模式 | Monorepo |

**不引入**：ORM、微服务拆分、GraphQL、Kafka/RabbitMQ 作为必需依赖、任何非官方数据库作为运行依赖、GPL/AGPL/SSPL 依赖。

---

## 二、架构边界

### 2.1 三个进程

```text
openwork-server     同步业务：HTTP API、认证、组织、权限、OA、考勤、应用平台
openwork-realtime   实时：WebSocket、在线状态、实时投递
openwork-worker     异步：Outbox 派发、工作流调度、Webhook、考勤计算、通知
```

三者共享 `internal/` 下的领域代码与基础设施。**禁止**在进程之间通过 HTTP 调用来完成本该是同进程的调用；跨进程协作只通过 MySQL（数据）与 Redis（Pub/Sub、presence）进行。

### 2.2 模块列表与职责

```text
internal/iam            用户、会话、凭据、OIDC 接入
internal/organization   租户、成员、部门树、组织事件
internal/authorization  权限目录、角色、数据范围、企业策略
internal/im             会话、消息、回执、附件元数据、部门群
internal/workflow       流程定义、版本、引擎、运行时
internal/attendance     打卡事件、排班、规则计算、假期账本、报表
internal/announcement   公告
internal/bot            机器人、卡片回调
internal/platform       应用、OAuth、凭据、WebView 上下文、连接器、Webhook
internal/infrastructure 数据库、Redis、存储、日志、指标、Outbox 基础设施
```

### 2.3 依赖方向（硬约束）

```text
cmd/  ──►  internal/<module>/handler ──►  application ──►  domain
                                              │
                                              ├──►  repository（接口在 application 或 domain 定义）
                                              └──►  infrastructure（实现）
```

规则：

- `domain` **不得** import `gin`、`database/sql`、`redis`、任何 `infrastructure`
- `application` **不得** import `gin`
- `handler` **不得**包含业务规则
- 模块之间**不得**互相 import `handler` / `application` 内部实现；跨模块协作通过显式导出的用例接口或领域事件
- 禁止循环依赖；CI 中有 import 图检查
- `infrastructure` 可以被任何层依赖，但它不得反向依赖具体业务模块

---

## 三、多租户铁律

1. 每个业务表必须有 `tenant_id`，且带索引；唯一约束必须包含 `tenant_id`
2. 每个 repository 方法必须接收携带租户的上下文；CI 静态检查会拦截缺失
3. 令牌中的 `tenant_id` 是唯一权威；请求体/查询参数中的租户标识只能用于校验，不能用于授权
4. Redis 键必须带租户前缀
5. 缓存值不得跨租户复用
6. 跨租户访问一律返回 404 或 403，不泄露资源是否存在
7. 任何跨租户路径必须有显式测试

---

## 四、权限铁律

1. 所有端点必须在服务端校验权限，客户端判断不构成授权
2. 权限码格式：`<module>.<resource>.<action>`，登记到权限目录，CI 校验
3. 数据范围（本人 / 本部门 / 本部门及下级 / 指定部门 / 全企业 / 指定资源）必须参与查询过滤，不能只在展示层过滤
4. 新增端点必须同时提交跨租户与无权限用例
5. 权限变更必须写审计日志

---

## 五、数据一致性

1. 跨聚合、跨模块的状态变更一律走 Transactional Outbox，禁止在业务事务中同步调用外部系统
2. 事件消费必须幂等：按事件 ID 去重，或使用可重入的状态机
3. 重试使用指数退避 + 抖动，并设置最大次数；超限进入死信表并告警
4. 长任务使用租约 + 心跳，进程崩溃后可被其他实例接管
5. 涉及金额、额度、工时的计算必须使用整数最小单位或 `DECIMAL`，禁止 `float`
6. 时间一律存 UTC，时间精度在 schema 中显式声明

---

## 六、API 规范

1. 契约先行：先改 `docs/api/openapi.yaml`，再生成服务端类型与客户端
2. 路径版本化：`/api/v1/...`
3. 统一响应包：数据、错误码、`request_id`
4. 统一分页：游标优先，列表接口必须有上限
5. 统一时间格式：RFC3339 UTC
6. 幂等：写操作支持 `Idempotency-Key`
7. 每个操作必须标注权限 scope 或显式声明公开
8. 破坏性变更需 major 版本递增，并提前 6 个月公告

错误响应：

```json
{
  "error": {
    "code": "ORGANIZATION.DEPARTMENT.NOT_FOUND",
    "message": "部门不存在",
    "details": {},
    "request_id": "..."
  }
}
```

---

## 七、代码风格

### Go

- 格式化：`gofmt` + `gofumpt` + `goimports -local github.com/OpenALC/open-work`
- 命名：包名小写单词；接口以行为命名；避免 `util` / `common` / `helper`
- 错误：`fmt.Errorf("...: %w", err)` 包装；哨兵错误用于可判定的业务分支；不吞错误
- 上下文：所有 I/O 带 `ctx`；超时在调用方设置
- 并发：说明所有权、关闭方式、生命周期；不使用裸 `go func()` 而不管理生命周期
- 日志：`slog` 结构化字段；敏感字段脱敏；不在热路径用 `fmt.Sprintf` 拼日志

### TypeScript / Vue

- 严格模式；禁止 `any`（必要时 `unknown` + 收窄）
- 组合式 API，`<script setup lang="ts">`
- 按 `api / stores / components / views / composables / utils` 分层
- 所有请求走统一 client，错误统一映射

### Dart

- `flutter analyze --fatal-infos` 零输出
- 原生能力经适配器接口，业务层不直接触碰 platform channel

---

## 八、测试策略

| 层 | 工具 | 要求 |
|---|---|---|
| Go 单元 | `go test` | 覆盖新增逻辑 ≥ 70%，含失败路径 |
| Go 集成 | `go test -tags=integration` | 真实 MySQL + Redis；覆盖事务、迁移、Outbox、并发 |
| 契约 | 基于 OpenAPI 的校验 | 端点与 schema 一致性 |
| 越权 | 参数化矩阵 | 每个端点 × 角色 × 租户 |
| Web | Vitest + Playwright | 关键路径 E2E |
| Flutter | `flutter test` | 状态与适配器层 |

禁止：跳过测试、放宽断言、用 mock 替代被测对象、只测 happy path。

---

## 九、AI 开发执行协议

### 9.1 工作单元

以**长任务（LT）**为唯一工作单元，见 [docs/development/roadmap.md](docs/development/roadmap.md)。一个 LT 内包含若干小任务（ST）。

### 9.2 执行流程

```text
1. 读任务卡 + 相关 ADR + 相关模块 README
2. 读现有代码，确认既有模式（不要发明新模式）
3. 逐条完成 ST，每个 ST 后运行相关测试
4. 完成全部 ST 后执行 make ci
5. 失败则修复，属于 LT 范围内的工作，不是阻塞点
6. 自查 DoD 清单
7. 提交 PR，按模板填写
8. 处理自动审查的阻断项
```

### 9.3 长任务内不设阻塞点

遇到以下情况**不要停下来等待确认**，按规则自行推进并记录：

| 情况 | 处理 |
|---|---|
| ADR 未覆盖的技术选择 | 按"最小可逆 + 与现有模式一致 + 不引入新依赖"决定，在 PR 里写一句"自决：xxx，因为 yyy"，继续执行 |
| 外部服务/密钥缺失 | 使用内存实现或 mock，保留接口，标 `TODO(adapter: <name>)` |
| 测试环境不可用 | 使用 CI 服务容器或本地 compose；不得降级为伪集成测试 |
| 同一 CI 失败连续修复 3 次无效 | 在 PR 的"遗留"一节记一句，继续后续 ST |
| 对写法没把握 | 按现有代码的路子来，拿不准就选改动最小的那个 |

### 9.4 必须停下来记一笔（仍不中断执行，按最保守方案实现）

- 数据破坏性迁移（删除列/表、不可逆变更）
- 许可证变更或新增不兼容依赖
- 删除或修改已发布的 API
- 涉及凭据、密钥、加密方案变更

在 PR 描述里单独列一节说明，等人工确认。

### 9.5 绝对禁止

- 跳过或删除测试、降低断言来让 CI 变绿
- `--no-verify`、`//nolint` 掩盖问题而不说明
- 修改已合并的迁移文件
- 手改生成代码
- 直接 push `main`
- 在 PR 中夹带无关重构
- 提交任何密钥、令牌、生产地址

### 9.6 提交前自检

- [ ] 新增查询都带租户作用域
- [ ] 新增端点都声明并校验权限
- [ ] 所有错误被处理或显式说明忽略原因
- [ ] 迁移可重复执行，命名合规
- [ ] OpenAPI 已更新并生成客户端无 diff
- [ ] 模块 README 与 CHANGELOG 已更新
- [ ] `TODO` 带 issue 引用或负责人
- [ ] 无调试残留、无敏感日志

---

## 十、文档要求

| 触发 | 必须产出 |
|---|---|
| 架构决策 | ADR（不可删除，被推翻时新增并标 `Supersedes`） |
| 新模块 | `internal/<module>/README.md`：职责、对外接口、数据表、依赖 |
| 新端点 | OpenAPI + 权限码登记 |
| 用户可见变更 | `CHANGELOG.md` |
| 新配置项 | `.env.example` 与部署文档 |

---

## 十一、提交与 PR

- Conventional Commits，`<type>(<scope>): <subject>`
- 一个 PR 对应一个 LT；≤ 1500 行变更（不含生成与测试数据）
- PR 描述必须含：目标、变更面、验证方式、风险与回滚、需人工决策
- Squash merge only

---

## 十二、参考文档

- [README.md](README.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/development/roadmap.md](docs/development/roadmap.md)
- [docs/development/ci.md](docs/development/ci.md)
- [docs/development/release.md](docs/development/release.md)
- [docs/development/review.md](docs/development/review.md)
- [docs/adr/](docs/adr/)
