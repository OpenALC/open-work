# OpenWork 里程碑与长任务规划

> 关联文档：[需求文档](../需求文档.md) · [CI 流程](./ci.md) · [发版流程](./release.md) · [审查流程](./review.md)
>
> 生效版本：v0（工程基线阶段）

---

## 一、规划约定

### 1.1 任务层级

| 层级 | 名称 | 规模 | 交付形态 | 审查方式 |
|---|---|---|---|---|
| M | 里程碑 | 2–6 周长任务集合 | 可演示、可发布的能力集合 | 里程碑出口集中人工审查 |
| LT | 长任务（Long Task） | 约 1.5k–4k 行变更（含测试） | 1 个 PR（必要时 ≤3 个堆叠 PR，同一 LT 内连续完成） | AI 自审 + 交叉审查 + 抽检 |
| ST | 小任务（Small Task） | 30–90 分钟 | 提交 | 由 LT 的 CI 统一验证 |

LT 是**唯一的工作单元**。LLM 领取一个 LT 后连续执行到 DoD 全部满足，中途不等待人工确认。

### 1.2 长任务内无阻塞点（核心机制）

为了让 LLM 能连续工作，LT 内部不允许出现需要人工决策的停点：

1. **决策前置冻结。** 所有需要拍板的技术选择在 M0 的 ADR 集中确定（模块边界、租户隔离、错误码、事件模型、权限模型、时间精度、测试策略等）。执行期只做实现，不做选型。
2. **未覆盖问题按默认策略推进。** 遇到 ADR 未覆盖的问题，按"最小可逆 + 与现有模式一致 + 不引入新依赖"三原则自行决定，把决策写入 `docs/adr/proposed/NNNN-<slug>.md`（状态 `Proposed`），然后**继续执行**，不中断、不等待确认。
3. **依赖只指向已完成的 LT。** LT 之间不出现"等你先做完产品确认"这类软依赖。有硬依赖时，依赖方提供 stub/接口，被依赖方后补实现。
4. **外部不可用即降级。** 缺少 API Key、真机、第三方服务时，使用内存实现或契约 mock，保留接口并标记 `TODO(adapter: <name>)`，不阻塞。
5. **测试必须自足。** 集成测试使用 CI 提供的真 MySQL 8.4 + Redis 7 服务容器，不依赖开发者本机或外部环境。
6. **CI 失败由执行者自行修复。** 失败的 job 属于 LT 范围内的工作，不是阻塞点。同一失败连续 3 次修复无效时，写入 `docs/development/known-issues.md` 并在 PR 中标明，继续后续 ST（不得跳过测试、不得降低断言）。
7. **不阻塞的边界。** 以下事项**必须**停下并记录，但仍不中断执行：涉及数据破坏性迁移、涉及许可证变更、涉及删除已发布的 API、涉及凭据或密钥——记录到 PR 的"需人工决策"章节，按最保守方案实现，由里程碑审查处理。

### 1.3 完成定义（DoD）

每个 LT 必须同时满足：

- [ ] `make ci` 全绿（fmt / vet / lint / 单测 / 集成测试 / 构建）
- [ ] 新增与修改逻辑单测覆盖 ≥ 70%，关键路径有真实 MySQL + Redis 集成测试
- [ ] 涉及数据库：新增 migration（可重复执行、含 down 或显式声明 forward-only）、sqlc 代码已生成
- [ ] 涉及 API：更新 `docs/api/openapi.yaml`，契约测试通过，生成客户端无 drift
- [ ] 涉及权限：权限码登记进权限目录，服务端强制校验，越权测试存在
- [ ] 涉及租户数据：所有查询显式带 `tenant_id`，通过静态检查与隔离测试
- [ ] 更新模块文档；在 `CHANGELOG.md` 的 Unreleased 段登记
- [ ] PR 描述含：目标、变更面、验证方式、风险与回滚方式、需人工决策事项

### 1.4 并行轨道

| 轨道 | 范围 | 启动条件 |
|---|---|---|
| A 后端 | Go：`cmd/`、`internal/`、`database/` | 从 M0 起 |
| B Web | Vue 3 + TS：`apps/web` | 依赖 A 已合并的 OpenAPI |
| C 客户端 | Flutter：`apps/flutter` | M5 起（API 稳定后） |
| D 平台 | CI、部署、文档、发布 | 贯穿全程 |

规则：A 先行，B 按 OpenAPI 生成的 TS 客户端对接，C 在 M5 启动，D 贯穿。同一里程碑内 A 的 LT 优先于 B 的同名能力。

---

## 二、里程碑总览

| 里程碑 | 主题 | LT 数 | 出口标准 |
|---|---|---|---|
| M0 | 工程基线 | 6 | 克隆即可一键运行；CI 全绿；三端骨架可构建；ADR 集冻结 |
| M1 | 身份 · 组织 · 权限 | 6 | 注册登录、建企业、无限级部门树、角色与数据范围可配；越权测试矩阵全绿 |
| M2 | 协作核心 IM | 8 | 两人实时聊天、部门群自动同步、机器人卡片可交互、离线补拉正确 |
| M3 | 流程与考勤 | 10 | 可视化设计审批流并跑通会签/或签；打卡 → 考勤结果可追溯重算 |
| M4 | 开放平台 | 6 | 第三方应用 OAuth 接入；连接器调通外部 HTTP；WebView 容器可用 |
| M5 | 多端与 GA | 8 | Flutter 五端构建；私有化一键部署与升级；`v1.0.0` 发布 |

---

## 三、M0 工程基线

**目标：** 让仓库从零到"任何人克隆后能跑起来、CI 能守住质量"。本里程碑的产出决定后续所有 LT 能否无人值守执行。

### L0.1 仓库骨架与三端可构建

**交付物：** monorepo 目录结构、Go 三进程骨架、Web 骨架、Flutter 骨架、开发用 compose、构建脚本。

**ST：**
- 落地 `cmd/{openwork-server,openwork-realtime,openwork-worker}`、`internal/`、`apps/{web,flutter}`、`packages/{contracts,connector-sdk,design-tokens}`、`database/`、`deploy/`、`docs/`、`scripts/`
- `go.mod`（Go 1.25，模块 `github.com/OpenALC/open-work`）
- 配置加载：环境变量 + yaml，启动期校验，敏感项不落日志
- 结构化日志（`slog`）：JSON、`request_id`、`tenant_id`、字段脱敏
- 统一错误码包 + 统一响应包 + 统一分页 + 统一时间格式（RFC3339，UTC）
- `/healthz`、`/readyz`、`/metrics` 三端点
- 三进程：信号处理、优雅退出、`ldflags` 版本注入
- `Makefile` 目标：`fmt vet lint test test-integration build ci web-install web-lint web-build flutter-analyze flutter-test migrate-up migrate-down openapi-lint`
- `apps/web`：Vite + Vue 3 + TS + Pinia + Vue Router + Naive UI 骨架，接入 `packages/design-tokens`
- `apps/flutter`：多平台工程骨架 + 分析配置
- `deploy/compose/docker-compose.dev.yml`：MySQL 8.4 + Redis 7 + 三进程，含健康检查与数据卷
- `docs/development/getting-started.md`

**验收：** `make ci` 绿；dev compose 起服务后 `/readyz` 返回 200；Web dev server 可访问；`flutter analyze` 零 issue。

### L0.2 CI 与仓库治理

**交付物：** GitHub Actions 流水线、代码规范配置、模板、CODEOWNERS。

**ST：**
- `.github/workflows/pr.yml`（路径过滤、并发取消、权限最小化）
- `.github/workflows/main.yml`（集成测试 + 覆盖率 + 镜像构建）
- `.github/workflows/nightly.yml`
- `.github/workflows/release.yml`（骨架，M5 启用）
- `.github/workflows/codeql.yml`、依赖审查
- `golangci-lint`、ESLint + Prettier、`analysis_options.yaml`
- commitlint + Conventional Commits 校验
- PR 模板、Issue 模板（bug / feature / security 走私有渠道）
- gitleaks、govulncheck、`pnpm audit`、依赖审查
- `.github/CODEOWNERS`
- 分支保护清单写入 `docs/development/branch-protection.md`
- 落地 [ci.md](./ci.md) 所述全部 job

**验收：** PR 触发全部 job 并给出可定位失败；故意引入格式、测试、密钥泄露各一次，三种情况都被拦截。

### L0.3 数据层基线

**交付物：** migration 体系、连接池、sqlc 管线、租户作用域强制机制、测试数据库工具。

**ST：**
- `database/migrations/mysql` 命名规范 + `000001_init` 基线迁移（schema_version 由 golang-migrate 管理）
- 连接池参数化配置、强制 UTC、语句超时、慢查询日志
- sqlc 配置与示例查询生成流程（`make sqlc`）
- 事务帮助器：从 `ctx` 取 tx，嵌套调用复用
- 租户作用域强制：repository 接口签名必须携带 tenant 上下文；提供静态检查脚本 + 单测，未带 `tenant_id` 的查询直接失败
- 测试基础设施：每测试独立 schema 或事务回滚；CI 使用服务容器
- `database/seeds`：演示租户、用户、部门树

**验收：** `make migrate-up && make migrate-down && make migrate-up` 可重复执行；故意写一条缺 `tenant_id` 的查询会被静态检查拦下。

### L0.4 Outbox 与 Worker 基线

**交付物：** 事务性 Outbox、事件派发器、Worker 进程骨架。

**ST：**
- `outbox_events` 表（事件 ID、类型、聚合、payload、可用时间、重试次数、租约、状态）
- 同事务写入 API
- 派发器：批量拉取 + 行级租约 + 幂等消费 + 指数退避 + 死信表
- `openwork-worker`：任务注册表、并发控制、优雅停机、处理指标
- 事件命名规范（`<module>.<aggregate>.<past-tense-verb>`）与 payload 版本字段
- 集成测试：并发派发下事件仅生效一次；进程 kill 后租约过期可恢复

**验收：** 并发 20 个派发器，单事件处理次数 = 1；进程强杀后 30 秒内事件被接管。

### L0.5 认证与请求治理中间件

**交付物：** 认证/租户/限流/幂等/审计基础设施。

**ST：**
- 认证：JWT 访问令牌 + Redis 会话；预留 OIDC 提供方接口
- 刷新令牌轮换与重放检测
- 租户解析（令牌声明优先，其次 host/header），解析失败统一 403
- RBAC 中间件占位（M1 填充实现）
- 幂等键中间件（`Idempotency-Key`）：Redis 记录请求指纹与响应
- 限流：Redis 令牌桶，按租户 + 用户 + 路由维度
- 审计日志：`audit_logs` append-only 表 + 异步写入 + 不参与业务事务回滚
- 请求日志脱敏规则（手机号、邮箱、令牌、密码、身份证）

**验收：** 重放同一 `Idempotency-Key` 返回首次响应且业务只执行一次；日志中不出现敏感字段原文。

### L0.6 架构与 AI 开发文档

**交付物：** 后续所有 LT 的"作业手册"。

**ST：**
- `AGENTS.md`：技术基线、模块边界、编码规范、禁做清单、LT 执行协议、PR 要求
- `docs/architecture/overview.md`
- ADR 0001–0012：模块边界、租户隔离、错误码、API 版本、时间与精度、幂等、Outbox、事件模型、存储抽象、权限模型、测试策略、AI 协作流程
- `CONTRIBUTING.md`、`SECURITY.md`、`CODE_OF_CONDUCT.md`、`CHANGELOG.md`、`README.md`
- `docs/development/{roadmap,ci,release,review}.md`
- `docs/development/known-issues.md`（空模板）

**验收：** 任一 LT 只读 `AGENTS.md` + 相关 ADR 即可开始实现，不需要额外提问。

---

## 四、M1 身份 · 组织 · 权限

**目标：** 打通"账号 → 企业 → 组织 → 权限"主干，形成可复用的纵切样板（后端 + Web）。

### L1.1 账号与会话

**ST：** `users` 模型与唯一性策略；argon2id 密码哈希；注册/登录/登出/刷新；多设备会话列表、单端撤销、全端撤销；修改密码（校验旧密码 + 撤销其他会话）；扫码登录状态机（`pending/scanned/confirmed/expired`）；登录风控（失败计数与锁定）；集成测试覆盖并发刷新不重放。
**验收：** 并发 10 次刷新只成功 1 次；撤销会话后旧令牌立即失效。

### L1.2 租户与成员

**ST：** `tenants` 模型与创建流程；企业列表与切换；邀请（链接 / 邮箱）→ 接受 → 生成 Membership；成员停用 / 离职 / 重新入职状态机；成员搜索与分页；CSV 批量导入（含错误行报告）；多企业身份隔离测试。
**验收：** 同一 User 在两个企业的数据完全隔离；离职后原企业 API 全部 403，其他企业不受影响。

### L1.3 组织架构

**ST：** `departments` + `department_closure`；创建/编辑/移动/排序/归档；多负责人；成员-部门多对多 + 主部门/兼职部门；单人/批量调动；`organization_events` 追加写入；按时间点还原组织快照的查询；子树/祖先查询；1 万部门规模的性能测试。
**验收：** 移动部门后 closure 表一致性测试通过；快照查询能还原任意历史时点的部门成员关系。

### L1.4 权限体系

**ST：** 权限目录（代码注册 + 启动同步到 DB）；`roles` / `role_permissions` / 角色作用域（企业/部门/资源）；`membership_roles` 绑定；数据范围计算（本人 / 本部门 / 本部门及下级 / 指定部门 / 全企业 / 指定资源）；企业策略（跨企业通讯、导出、会话时长）；权限缓存与失效；权限变更审计；越权测试矩阵（接口 × 角色）。
**验收：** 越权矩阵全部返回 403；权限变更后 5 秒内生效且缓存无脏读。

### L1.5 Web 管理后台

**ST：** 设计 token 与主题；登录 / 企业切换 / 路由守卫；部门树（拖拽、批量）；成员管理；角色权限配置（矩阵勾选 + 数据范围）；权限驱动的菜单与按钮；Playwright 冒烟。
**验收：** 完整走通"建企业 → 邀成员 → 建部门树 → 配角色 → 成员登录看到正确菜单"。

### L1.6 隔离与权限测试套件

**ST：** 跨租户越权 fuzz；SQL 层 `tenant_id` 强制检查；OpenAPI 中的权限标注与运行时一致性测试；安全回归用例集。
**验收：** 测试套件进入 CI 常驻，后续 LT 破坏隔离会立即失败。

---

## 五、M2 协作核心 IM

**目标：** 实时协作闭环，含部门群自动同步与机器人卡片。

### L2.1 会话与消息模型
`conversations` / `conversation_members` / `messages` / `message_receipts`；会话内单调序号分配；幂等发送；撤回；编辑（文本）；引用与回复；转发；搜索；历史分页；离线增量补拉游标。

### L2.2 实时网关 `openwork-realtime`
WS 鉴权与连接生命周期；Redis presence；在线消息投递；多端同步；断线重连与补偿；心跳与超时；多实例广播（Redis Pub/Sub）；网关指标。

### L2.3 部门群自动同步
组织事件 → Outbox → 群成员重算；父部门群包含本部门与全部下级成员并按成员身份去重；群名同步；负责人 → 群管理权限同步；部门移动时新旧祖先群重算；部门归档 → 群归档；离职即时阻断（不依赖异步完成）。

### L2.4 附件与存储
Storage Interface（Local + S3）；上传 / 下载 / 删除 / 元数据；预签名 URL；访问授权校验；缩略图与转码任务；大小与类型限制；病毒扫描钩子位。

### L2.5 好友与跨企业通讯
好友关系（基于 User）；企业策略（完全禁止 / 主动添加 / 指定企业白名单 / 限单聊 / 限通讯录可见）；外部身份展示规则；跨企业与跨租户判定分离。

### L2.6 机器人与消息卡片
机器人独立身份与令牌；事件订阅；Webhook 回调 + 验签；发送限流；卡片 Schema（标题/文本/图片/状态/按钮/链接/业务数据/操作回调）；卡片渲染数据；操作回调的服务端鉴权与状态校验。

### L2.7 Web IM 客户端
会话列表；聊天窗口；消息搜索；已读回执；群管理；卡片交互；免打扰与置顶。

### L2.8 推送与离线通知
推送抽象（APNs / FCM / Web Push）；通知偏好；免打扰时段；离线消息唤醒；推送失败重试与失效清理。

---

## 六、M3 流程与考勤

**目标：** OA 审批与考勤两大业务核心。

### L3.1 工作流定义与版本
`workflow_definitions` / `versions` / `nodes`；动态表单 Schema；发布/停用；已发布版本不可变；导入导出；实例绑定版本。

### L3.2 引擎核心
持久化状态机；`workflow_instances` / `tokens` / `tasks` / `actions` / `variables` / `executions` / `events`；开始/结束/人工审批；会签（全票通过，任一拒绝即节点拒绝）；或签（任一通过即节点完成，其余任务关闭）；抄送（不阻塞）；条件分支；并发控制与幂等；崩溃恢复。

### L3.3 扩展节点
外部 API 查询 / 执行节点（超时、重试、错误映射）；定时等待；并行分支与汇聚；子流程；外部操作补偿。

### L3.4 审批 API 与人工操作
提交 / 同意 / 拒绝 / 撤回 / 抄送；审批进度与记录；代理；转交；管理员终止（与撤回、撤销分离权限与状态）。

### L3.5 可视化设计器
Vue Flow 画布；节点拖拽与连线；表单设计器；审批人与条件配置；版本发布与历史版本对比；预览与校验。

### L3.6 考勤基础
班次模板（固定/弹性/跨日/夜班）；轮班周期与规则（三班倒、三班两倒、自定义）；排班计划与临时调班；班组排班；`AttendanceEvent` 统一打卡事件（来源、设备、定位、网络、验证结果、风险）；GPS 围栏；Wi-Fi SSID/BSSID 白名单；设备接入协议与厂商适配器；离线补传与去重。

### L3.7 考勤计算引擎
规则化计算（迟到/早退/缺卡/旷工/跨日/夜班/休息日/法定节假日/企业节假日/调休工作日/弹性工时/加班认定）；结果版本追溯；按规则版本重算；批量重算任务。

### L3.8 假期额度与工时
假期类型与额度账本（发放/扣减/结转/失效，含来源、时间、规则版本、审批关联）；余额查询；加班申请与审批；正常/夜班/缺勤工时；部门工时统计。

### L3.9 报表与导出
个人日报/月报；部门与企业汇总；迟到早退、缺卡、加班、请假、工时统计；异步导出（CSV/XLSX）与下载授权。

### L3.10 OA 联动
补卡 / 请假 / 调班 / 加班审批；审批通过 → 业务事件 → 重算受影响考勤；重算幂等与版本记录。

---

## 七、M4 开放平台

### L4.1 OpenAPI 契约源与代码生成
OpenAPI 3.1 源文件组织；`spectral` 规则；`oasdiff` 破坏性变更检测；Go 服务端类型与 TS 客户端生成；drift 检查；契约测试；API 版本化策略。

### L4.2 应用与凭据
企业应用注册 / 安装 / 启停 / 权限授权 / 入口配置 / 版本管理；OAuth 2.0 授权码 + 客户端凭据；Scope 授权；API 凭据轮换；按应用限流；调用审计。

### L4.3 连接器平台
HTTP 连接器配置（地址、方法、鉴权、参数、响应映射、超时、重试、错误处理）；字段映射与身份映射；SSRF 防护与网络目标限制；凭据加密存储；执行日志与脱敏；Connector SDK（Go / TS）+ 独立进程协议。

### L4.4 Webhook 与事件订阅
订阅管理；签名与时间戳；重放保护；重试与死信；投递日志；事件回放。

### L4.5 应用平台与 WebView 容器
工作台入口与导航；OAuth 登录；应用上下文注入；受控 JS Bridge（文件、相机、定位、通知、导航）；每次调用校验应用身份、页面来源、Scope、用户授权、企业策略；JS SDK 发布。

### L4.6 企业公告
公告 CRUD；发布 / 撤回 / 置顶；范围（企业/部门/人员）；有效期；阅读状态与回执；IM 通知联动；公告管理 UI。

---

## 八、M5 多端与 GA

### L5.1 Flutter 基础框架
主题与设计 token 对齐；路由；网络层（鉴权、重试、错误映射）；本地存储与安全存储；状态管理；原生能力适配器抽象；登录与企业切换。

### L5.2 Flutter IM
会话与消息；离线同步与补拉；WS 重连；推送接入；消息操作。

### L5.3 Flutter 业务能力
审批列表与操作；考勤打卡（GPS / Wi-Fi / 人脸封装的接口层）；公告；工作台 WebView。

### L5.4 Flutter 多平台构建与发布
Android / iOS / Windows / macOS / Linux 构建矩阵；签名与自动发布工作流；崩溃上报。

### L5.5 可观测性
OpenTelemetry traces / metrics / logs；关键 SLO（API p95、WS 投递延迟、Outbox 积压、审批节点耗时）；仪表盘与告警规则；trace 贯穿 HTTP → Worker → WS。

### L5.6 私有化部署与升级
compose bundle（生产版）；安装脚本与配置校验；升级与回滚脚本；迁移执行与备份恢复；离线安装包；部署文档与最小资源建议。

### L5.7 安全加固
多租户隔离 fuzz 扩展；限流与防爆破策略；审计完整性校验；依赖升级；WebView Bridge 渗透自查；密钥管理；安全公告模板。

### L5.8 v1.0 GA
文档站；快速开始；API 文档；兼容性矩阵；升级指南；Release Notes；镜像与制品签名。

---

## 九、执行顺序与并行建议

```text
M0  ──►  M1  ──►  M2  ──►  M3  ──►  M4  ──►  M5
        │        │
        │        ├─ L2.7 Web IM（B 轨，依赖 L2.1/L2.2 API 合并后）
        ├─ L1.5 Web 管理后台（B 轨，依赖 L1.4 API 合并后）
        └─ M4/L4.5 可与 M5 并行
M5.L5.1–L5.4（C 轨）依赖 M2 + M3 API 冻结
```

并行上限建议：同时进行 ≤ 3 个 LT，且必须位于不同轨道或不同模块，避免同一 `internal/<module>` 目录并发冲突。

---

## 十、里程碑出口审查

每个里程碑结束时执行一次集中人工审查（详见 [review.md](./review.md)）：

1. 全量 CI + nightly 结果复核
2. 演示脚本执行（可重复的一键 demo）
3. 安全清单复核：租户隔离、权限校验、密钥、迁移
4. 文档完整性核对：模块文档、OpenAPI、CHANGELOG
5. 遗留事项归档到 `docs/development/known-issues.md`
6. 打里程碑标签 `milestone/m0` 等

---

## 十一、风险与应对

| 风险 | 影响 | 应对 |
|---|---|---|
| LT 粒度过大导致单次执行超长 | 上下文耗尽、返工 | LT 控制在 ≤4k 行变更；超出则拆分为 LT.n.1 / LT.n.2，并在依赖表中登记 |
| 权限模型返工 | 全模块受影响 | M1 的 ADR 与越权矩阵先冻结再实现；后续模块只扩展不重写 |
| IM 顺序与幂等设计缺陷 | 消息错乱、重复 | L2.1 先用状态机与不变量测试锁死语义，再接入网关 |
| 工作流引擎状态机缺陷 | 审批卡死 | L3.2 要求崩溃恢复测试与幂等重放测试为 DoD 硬项 |
| 考勤规则复杂度超预期 | 排期膨胀 | 规则表驱动 + 规则版本化；计算与展示分离，报表后置 |
| 依赖上游不可用 | 阻塞 | 接口先行 + mock；SDK/第三方服务统一走适配器 |
| 迁移不可逆导致线上事故 | 数据损坏 | expand/contract 策略 + 升级矩阵测试（见 release.md） |

---

## 十二、任务卡模板（LT 执行时使用）

```markdown
## LT-<id> <标题>

**目标：** 一句话
**前置：** 已完成的 LT 列表
**范围：** 涉及目录 / 模块
**交付物：** 文件或能力清单
**ST 清单：** （逐条，可勾选）
**验收：** 可自动验证的断言
**不做：** 明确排除的内容
**风险 / 回滚：**
**需人工决策（不阻塞执行）：**
```
