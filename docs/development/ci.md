# OpenWork CI 流程

> 关联文档：[里程碑规划](./roadmap.md) · [发版流程](./release.md) · [审查流程](./review.md)
>
> 平台：GitHub Actions · 目标：单次 PR 反馈 ≤ 12 分钟（P50）

---

## 一、设计原则

1. **快反馈优先。** 最贵的检查放到最后，最先失败的 job 最先取消其他 job。
2. **确定性。** 所有检查固定版本（Go、Node、Flutter、linter、MySQL、Redis、action 版本），不使用 `latest`。
3. **本地可复现。** 每个 CI job 都有对应的 `make` 目标，本地 `make ci` 与 CI 等价。
4. **失败可定位。** 失败必须指向文件与行号，并回传结构化摘要到 PR 评论。
5. **最小权限。** `permissions:` 按 job 显式声明；第三方 action 固定到 commit SHA。
6. **不跳过。** 禁止 `--no-verify`、禁止条件跳过测试、禁止降低断言来让 CI 变绿。

---

## 二、流水线分类

| 流水线 | 触发 | 目标 | 最大时长 |
|---|---|---|---|
| `pr.yml` | PR → `main` | 变更范围检查、快速反馈 | 15 min |
| `main.yml` | push → `main` | 全量验证 + 镜像 + 覆盖率基线 | 35 min |
| `nightly.yml` | 每日 UTC 18:00 | 全量 + 竞态 + 性能 + 依赖漏洞 | 90 min |
| `release.yml` | tag `v*` | 制品、镜像、Release | 120 min |
| `codeql.yml` | PR / main / 每周 | 静态安全分析 | 30 min |

`pr.yml` / `main.yml` 使用 `concurrency: group: <workflow>-<ref>, cancel-in-progress: true`。

---

## 三、路径过滤

| 变更路径 | 触发的 job |
|---|---|
| `**.go`, `go.mod`, `go.sum`, `database/**` | `go-*` |
| `apps/web/**`, `packages/**`, `package.json`, `pnpm-lock.yaml` | `web-*` |
| `apps/flutter/**` | `flutter-*` |
| `database/migrations/**` | `migration-check` |
| `docs/api/**`, `packages/contracts/**` | `openapi-check` |
| `deploy/**`, `Dockerfile*` | `docker-build` |
| `**` | `secrets-scan`, `license-check`, `commit-lint` |

文档、CI 自身变更不触发构建类 job（`docs/**`, `.github/**` 单独路径）。

---

## 四、`pr.yml` Job 清单

### 4.1 门禁类（并行，最先执行）

| Job | 内容 | 失败含义 |
|---|---|---|
| `commit-lint` | commitlint 校验 Conventional Commits，≤ 3 次提交且非 merge 时额外校验 squash 标题 | 提交信息不合规 |
| `secrets-scan` | gitleaks 全历史 + 当前 diff | 检出密钥 |
| `license-check` | 依赖许可证白名单（Apache-2.0 / MIT / BSD / ISC / MPL-2.0），禁止 GPL/AGPL/SSPL 进入核心 | 引入不兼容依赖 |
| `pr-size` | 变更行数 > 1500（非生成文件）时打 `size/large` 标签并提示拆分 | 仅提示，不阻塞 |
| `scope-check` | 变更跨模块数 > 3 时提示拆分 | 仅提示 |

### 4.2 Go

| Job | 命令 | 说明 |
|---|---|---|
| `go-fmt` | `gofmt -l .` + `gofumpt` + `goimports -local` | 任何未格式化文件即失败 |
| `go-vet` | `go vet ./...` | |
| `go-lint` | `golangci-lint run --timeout=10m` | 配置 `.golangci.yml` |
| `go-build` | `go build ./...` 三进程 + `GOOS/GOARCH` 交叉编译检查 | |
| `go-test` | `go test -race -shuffle=on -coverprofile` | 单元测试，不需要外部服务 |
| `go-integration` | 服务容器 MySQL 8.4 + Redis 7，`go test -tags=integration` | 真实事务、迁移、Outbox |
| `go-mod-tidy` | `go mod tidy` 后工作区必须无 diff | 依赖未整理 |
| `sqlc-check` | `sqlc generate` 后必须无 diff | 查询与生成代码不同步 |
| `tenant-scope` | 静态检查：所有 repository SQL 必须含租户作用域或显式豁免注释 | 租户隔离风险 |

覆盖率：`go-test` 与 `go-integration` 合并后，变更包覆盖率 ≥ 70%，整体不得下降 > 0.5%。

### 4.3 Web

| Job | 命令 |
|---|---|
| `web-install` | `pnpm install --frozen-lockfile` |
| `web-lint` | `eslint . --max-warnings=0` |
| `web-format` | `prettier --check` |
| `web-typecheck` | `vue-tsc --noEmit` |
| `web-build` | `pnpm build`，产物体积预算检查 |
| `web-test` | `vitest run --coverage` |
| `web-e2e` | `playwright test`（仅 `apps/web/**` 变更，`main` 分支必跑） |

### 4.4 Flutter

| Job | 命令 |
|---|---|
| `flutter-analyze` | `flutter analyze --fatal-infos --fatal-warnings` |
| `flutter-format` | `dart format --output=none --set-exit-if-changed .` |
| `flutter-test` | `flutter test --coverage` |
| `flutter-build` | `flutter build apk --debug`（PR 仅 Android；`main` 扩展 web/linux/windows） |

M5 起 iOS/macOS 构建在 `main.yml` 与 `release.yml` 中执行（需要 macOS runner）。

### 4.5 契约与数据库

| Job | 内容 |
|---|---|
| `openapi-lint` | `spectral lint docs/api/openapi.yaml`，规则集 `.spectral.yaml` |
| `openapi-breaking` | `oasdiff breaking` 对比 `main` 分支，非 `major` 版本禁止破坏性变更 |
| `openapi-codegen` | 重新生成 Go 服务端类型与 TS 客户端，工作区必须无 diff |
| `openapi-permission` | 每个 `operationId` 必须声明权限 scope 或显式 `x-public`/`x-authenticated` |
| `migration-check` | 迁移文件命名规范；顺序连续；禁止修改已合并迁移；`migrate up → down → up` 可重复执行；每个 `tenant` 表必须含 `tenant_id` 索引 |
| `migration-explain` | 新迁移的 DDL 在 10 万行种子数据上执行 `EXPLAIN`，全表扫描或锁表超阈值告警 |

### 4.6 安全

| Job | 内容 |
|---|---|
| `govulncheck` | Go 官方漏洞库，仅报告可达漏洞 |
| `pnpm-audit` | `pnpm audit --audit-level=high` |
| `dependency-review` | 新增依赖的许可证、漏洞、维护状态 |
| `codeql` | Go + TypeScript 分析集 `security-extended` |

### 4.7 构建

| Job | 内容 |
|---|---|
| `docker-build` | 三进程多阶段构建，使用 buildx 缓存；仅 `deploy/**`、`Dockerfile*`、`**.go` 变更时执行 |
| `compose-validate` | `docker compose -f deploy/compose/*.yml config` 校验；启动 dev compose 并等 `/readyz` 通过 |

---

## 五、`main.yml`

在 `pr.yml` 全部 job 基础上追加：

| Job | 内容 |
|---|---|
| `coverage-report` | 合并覆盖率，上传 Codecov，更新 README 徽章，低于基线则失败 |
| `race-stress` | 关键包 `go test -race -count=5` |
| `image-push` | 构建并推送 `ghcr.io/openalc/open-work-{server,realtime,worker}:main-<sha>`，打 `edge` 标签 |
| `sbom` | 生成 SPDX SBOM 并与镜像一起上传 |
| `e2e-full` | 起完整 compose 栈，跑端到端场景（登录 → 建部门 → 发消息 → 提审批 → 打卡） |

---

## 六、`nightly.yml`

| Job | 内容 |
|---|---|
| `full-integration` | 全部集成测试，`-shuffle=on -count=2` |
| `concurrency-stress` | Outbox 并发派发、WebSocket 多实例投递、审批会签并发 |
| `tenant-isolation-fuzz` | 跨租户访问 fuzz，随机生成租户/资源组合断言 403 |
| `db-compat` | 迁移在空库与 1 年历史数据快照上各跑一遍 |
| `perf-smoke` | 关键接口基准（组织树查询、消息增量拉取、审批提交），相对基线回归 > 20% 失败 |
| `flutter-full-build` | 五端构建 |
| `dependency-freshness` | 过期依赖报告（仅报告） |

Nightly 失败自动开 issue 并打 `nightly-failure` 标签，指派人由 CODEOWNERS 决定。

---

## 七、缓存策略

| 缓存 | 键 |
|---|---|
| Go modules + build | `go-<go.sum hash>` |
| golangci-lint | `lint-<.golangci.yml hash>-<go version>` |
| pnpm store | `pnpm-<pnpm-lock.yaml hash>` |
| Flutter SDK | `flutter-<channel>-<version>` |
| Docker layer | `gha:buildx-<image>:<branch>` |
| Playwright browsers | `pw-<playwright version>` |

命中率低于 60% 视为需要修复的 CI 问题。

---

## 八、分支策略（不使用 GitHub 分支保护）

**当前明确不使用 GitHub 分支保护规则**（Rulesets / Branch protection）。`main` 上没有任何强制检查、审批或推送限制。

### 8.1 为什么

| 原因 | 说明 |
|---|---|
| 单人维护阶段 | GitHub 不允许批准自己创建的 PR；强制审批会把 `main` 锁死 |
| 骨架未落地 | required status checks 在骨架文件存在的动作触发前不会被上报，未触发的检查会被判为 pending，从而永久阻塞合并 |
| 流程尚未稳定 | 早期频繁调整 CI 与目录结构，硬门禁的维护成本高于收益 |

### 8.2 替代约束

保护不靠平台强制，靠流程与自律。以下仍然必须遵守：

| 约束 | 执行方式 |
|---|---|
| 提交前跑 `make ci` | 由 [review.md](review.md) §二的自我审查条目约束 |
| 不直接往 `main` 推未经验证的代码 | 小改动可直推，但必须本地 `make ci` 通过；跨模块或涉及迁移/权限/安全的改动走 PR |
| 走 PR 的改动必须 CI 全绿才合并 | 以 `pr-summary` job 结论为准，不看单个 job |
| 不 force push 已推送的 `main` | 避免历史改写导致他人本地分叉 |
| 保持线性历史 | 合并使用 Squash Merge（仓库设置已强制 squash-only） |

### 8.3 什么情况下重新启用

满足以下全部条件时，重新评估是否启用分支保护：

1. 至少有 2 名具有写权限的维护者（解决自批问题）
2. M0 骨架落地，`go-*` / `web-*` / `flutter-*` / `openapi-*` / `docker-*` 各组检查能稳定上报
3. 近 30 天内 `pr.yml` 的基础设施失败率 ≤ 10%

启用时按 [branch-protection.md](branch-protection.md) 的配置表执行，并先只勾选 `commit-lint` 与 `secrets-scan`，其余逐项加入。


---

## 九、CI 异常处理

| 场景 | 处理 |
|---|---|
| 基础设施导致失败（runner 卡死、缓存损坏、服务容器未就绪） | 重新运行 job；同一 job 重跑 ≥ 2 次仍在非代码环节失败，标记 `ci-flake` 并记入 `known-issues.md` |
| 检查本身有问题（误报） | 修检查，不修代码；禁止用 `//nolint` 绕过，除非在同一 PR 中说明并附 issue |
| 需要的服务在 CI 不可用 | 用服务容器替代；不得退化为 mock 冒充集成测试 |
| 流水线时长超标 | 优先拆分 job 并行化、改善缓存，其次调整路径过滤；不得砍检查项 |

---

## 十、本地等价命令

```bash
make ci              # 等价 PR 全部门禁 + 单元测试 + 构建
make ci-full         # 含集成测试（需要 local MySQL/Redis 或 dev compose）
make ci-web          # Web 全流程
make ci-flutter      # Flutter 全流程
make ci-contract     # OpenAPI + 迁移检查
make ci-security     # 漏洞与密钥扫描
```

`make ci` 与 CI 的差异仅限：不使用 Codecov 上传、不推送镜像、不跑 macOS runner 专属任务。
