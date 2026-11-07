# OpenWork 发版流程

> 关联文档：[里程碑规划](./roadmap.md) · [CI 流程](./ci.md) · [审查流程](./review.md)
>
> 版本规范：Semantic Versioning 2.0.0 · 分发：GHCR 镜像 + 制品包 + 源码标签

---

## 一、版本体系

产品版本、开放 API 版本、Connector SDK 协议版本、数据库迁移版本**分别独立管理**，不互相绑定。

| 版本线 | 位置 | 规则 |
|---|---|---|
| 产品版本 | Git tag `v1.2.3` | SemVer；预发布后缀 `-alpha.N` / `-beta.N` / `-rc.N` |
| 开放 API 版本 | URL 路径 `/api/v1`、`/api/v2` | 只增不减；`v1` 支持期内双写 |
| Connector SDK 协议版本 | `packages/connector-sdk`，`protocol: 1` | 加字段为 minor，删改字段为 major |
| 数据库迁移版本 | `database/migrations/mysql` 序号 | 只增不改；应用版本注明兼容的迁移区间 |

### 1.1 版本递增判定

| 变更 | 递增 |
|---|---|
| 破坏性 API 变更、数据库不兼容变更、需人工介入的升级步骤 | MAJOR |
| 新增 API / 新模块 / 新权限码 / 新配置项（有默认值） | MINOR |
| 缺陷修复、性能优化、文档、内部重构 | PATCH |
| 安全修复 | PATCH（必要时单独发布 `vX.Y.Z+security` 说明） |

预发布版本不承诺升级路径，仅用于验证。

---

## 二、分支与标签模型

采用 Trunk-Based Development：

```text
main ────●────●────●────●────●────●──────►
         │         ╲        ╱
         │          ●──────●            release/1.2（仅在需要长时间稳定化时创建）
         │                   ╲
         └── tag v1.2.0-rc.1  v1.2.0
```

- 日常开发只在 `main` 与短生命周期的 `feat/*`、`fix/*` 上。
- `release/x.y` 仅在需要并行稳定化（同时开发下一 minor）时创建，生命周期 ≤ 4 周。
- 标签为轻量语义标签 + 签名（`git tag -s`），`v*` 标签即发布触发器。
- `main` 上的提交必须始终可发布；不允许"只存在于 release 分支"的修复。

---

## 三、发布类型

| 类型 | 版本示例 | 触发 | 审批 | 产物 |
|---|---|---|---|---|
| Nightly / Edge | `edge-<sha>` | 每次 `main` 合并 | 无 | GHCR `edge` 镜像 |
| Alpha | `v0.x.0-alpha.N` | 里程碑内 | 1 名维护者 | 预发布 Release |
| Beta | `v1.0.0-beta.N` | 里程碑出口 | 2 名维护者 | 预发布 Release |
| RC | `v1.0.0-rc.N` | 发布候选 | 2 名维护者 + 发布负责人 | 预发布 Release，禁止新增功能 |
| GA | `v1.0.0` | RC 通过稳定期（≥ 7 天无 P0/P1） | 2 名维护者 + 发布负责人 | 正式 Release |
| Patch | `v1.0.1` | 缺陷/安全修复 | 1 名维护者 | 正式 Release |
| 安全紧急 | 见 §八 | 安全事件 | 安全负责人 + 1 名维护者 | 正式 Release |

---

## 四、发布前检查清单

发布负责人逐项确认并在 Release PR 中留痕：

### 4.1 代码与质量

- [ ] `main` HEAD 的 `main.yml` 全绿，且最近 3 次 `nightly.yml` 无失败
- [ ] 覆盖率未低于基线
- [ ] 无 `P0` / `P1` 未关闭缺陷
- [ ] 所有 `release/x.y` 相关 PR 已合入
- [ ] `CHANGELOG.md` 已按 Keep a Changelog 格式补齐本版本段落，条目与 commit 类型一致

### 4.2 契约与数据

- [ ] `docs/api/openapi.yaml` 版本标注与产品版本对应
- [ ] `oasdiff` 相对上一版本无非预期破坏性变更（有则已在 CHANGELOG 的 `Breaking Changes` 说明）
- [ ] 迁移链在空库与上一 GA 版本数据快照上均可执行
- [ ] 迁移可回滚性已确认（forward-only 的已显式声明并写入升级指南）
- [ ] seed 与 demo 数据可重置

### 4.3 安全

- [ ] `govulncheck` / `pnpm audit` / `dependency-review` 无 high 及以上可达漏洞
- [ ] `gitleaks` 全历史扫描通过
- [ ] 越权测试矩阵全绿
- [ ] 依赖许可证白名单通过
- [ ] 新增权限码已登记且服务端强制校验

### 4.4 部署

- [ ] `deploy/compose/` 与 Dockerfile 变更已通过 `compose-validate` 与端到端冒烟
- [ ] 从 `v<上一版本>` 升级到本版本的升级演练完成（记录耗时与步骤）
- [ ] 回滚演练完成（含数据库）
- [ ] 最小资源建议、端口、环境变量清单已更新到部署文档

### 4.5 客户端

- [ ] Flutter 五端构建全部成功
- [ ] Android / iOS 签名配置有效，版本号与 build number 正确递增
- [ ] 桌面端安装包可安装、可卸载
- [ ] 旧客户端连新服务端：兼容期验证通过（至少覆盖上一 minor 版本）
- [ ] 新客户端连旧服务端：降级行为已验证或明确拒绝

### 4.6 文档

- [ ] 快速开始、升级指南、兼容性矩阵、API 文档已更新
- [ ] `docs/development/known-issues.md` 已更新
- [ ] Release Notes 已撰写（面向使用者的能力说明 + 面向运维的变更说明）

---

## 五、发版执行步骤

### 5.1 发起 Release PR

```bash
git switch main && git pull --ff-only
git switch -c chore/release-v1.2.0
```

1. 更新 `CHANGELOG.md`：把 `Unreleased` 迁移到 `[1.2.0] - YYYY-MM-DD`
2. 更新版本常量（`internal/version/version.go` 之外仅保留 `ldflags` 注入，避免多处真值）
3. 更新 `docs/development/compatibility.md` 兼容性矩阵
4. 更新 OpenAPI 的 `info.version`
5. 提交 `chore(release): v1.2.0`，开 PR，标题 `chore(release): v1.2.0`

### 5.2 打标签

合并后：

```bash
git switch main && git pull --ff-only
git tag -s v1.2.0 -m "v1.2.0"
git push origin v1.2.0
```

标签推送触发 `release.yml`，不会有人手动上传制品。

### 5.3 `release.yml` 流水线

```text
preflight
  ├─ 校验 tag 格式与分支来源（必须在 main 的可达历史中）
  ├─ 校验 CHANGELOG 存在对应段落
  ├─ 复用 main 的最新全量 CI 结果；否则重跑全部门禁
  └─ 校验版本一致性（tag / go ldflags / package.json / pubspec / openapi info）

build（并行）
  ├─ 三进程镜像 linux/amd64 + linux/arm64
  ├─ compose bundle（含默认配置、安装脚本、示例 .env）
  ├─ Flutter：Android APK/AAB、Web、Windows、macOS、Linux
  ├─ Connector SDK：Go 模块 zip、npm 包
  └─ SBOM（SPDX）与出处证明（provenance attestation）

verify
  ├─ 用产物起完整栈，跑 e2e 冒烟
  ├─ 升级演练：v<上一 GA> → 本版本
  └─ 镜像漏洞扫描（trivy，修复前禁止发布 critical）

publish
  ├─ 推送镜像：ghcr.io/openalc/open-work-*:1.2.0, :1.2, :latest（预发布不打 latest）
  ├─ 镜像签名（cosign keyless）
  ├─ 创建 GitHub Release（草稿 → 人工核对 → 发布）
  ├─ 上传制品、校验和（SHA256SUMS）、SBOM
  └─ 生成 Release Notes（按 Conventional Commits 分组，标注 Breaking Changes）

post-release
  ├─ 打 milestone 标签、关闭对应 milestone
  ├─ 同步文档站
  └─ 通知渠道发布（GitHub Discussions / 公告）
```

### 5.4 发布后校验

- 用官方 compose bundle 在干净环境安装一次，验证 `/readyz`、登录、建部门、发消息
- 校验镜像 digest 与 Release 中记录一致
- 校验 `cosign verify` 通过
- 24 小时内监控 issue 与 Discussions，P0/P1 立即进入 §八

---

## 六、数据库迁移发布策略

采用 **expand / contract**（先扩展后收缩），保证发布过程中新旧版本可同时运行：

| 阶段 | 做法 |
|---|---|
| N（本次） | 新增列/表、双写、回填、读路径兼容新旧 |
| N+1 | 切换读路径到新结构 |
| N+2 | 删除旧列/旧表 |

规则：

- 一次发布不删除任何被上一版本使用的列或表
- 大表加索引使用 online DDL（`ALGORITHM=INPLACE, LOCK=NONE`）或分批回填
- 回填任务作为 Worker 任务，可暂停、可续跑、可校验
- 迁移执行入口：`openwork-server migrate`（单一入口，禁止应用启动时隐式执行）
- 每个迁移在 CHANGELOG 标注可回滚性

---

## 七、回滚

| 场景 | 手段 | 时限 |
|---|---|---|
| 应用逻辑缺陷，数据兼容 | 镜像回退到上一 tag（`compose` 中改 `IMAGE_TAG`） | ≤ 10 分钟 |
| 数据库迁移有问题 | 执行对应 down 迁移；forward-only 迁移走备份恢复 | ≤ 60 分钟 |
| 客户端问题 | 服务端兼容旧客户端；应用商店回滚不现实，用服务端开关降级 | ≤ 30 分钟 |
| 安全事件 | 见 §八 | 立即 |

回滚触发条件（任一）：错误率 > 5% 且持续 5 分钟、核心路径不可用、数据一致性问题、越权漏洞。

每次回滚必须产出事后复盘（`docs/development/incidents/YYYY-MM-DD-<slug>.md`）。

---

## 八、安全发布（CVE / 紧急）

1. 在**私有**安全公告草稿中处理，不在公开 PR 中描述细节
2. 修复提交直接用 `fix(security): ...`，合并后立即打 patch tag
3. 镜像推送后立即发布 GitHub Security Advisory，说明受影响版本、修复版本、缓解措施
4. 同时向 `SECURITY.md` 中登记的渠道发通知
5. 严重等级 P0：目标 24 小时内出修复版本；P1：72 小时

---

## 九、制品与供应链

| 制品 | 位置 | 校验 |
|---|---|---|
| 容器镜像 | `ghcr.io/openalc/open-work-{server,realtime,worker}` | cosign 签名 + SBOM + provenance |
| 服务端二进制 | Release assets，linux/darwin/windows × amd64/arm64 | `SHA256SUMS` |
| 私有化 bundle | `openwork-<version>-compose.tar.gz` | `SHA256SUMS` + 内嵌 `VERSION` |
| Flutter 客户端 | Release assets + 应用商店 | APK 签名指纹公开 |
| Connector SDK | `packages/connector-sdk` 发布 + Go module tag | 模块校验和 |
| 源码 | Git tag + GitHub 自动生成归档 | tag 签名 |

`latest` 标签只指向最新 GA；预发布版本不加 `latest`。

---

## 十、兼容性承诺

| 对象 | 承诺 |
|---|---|
| 开放 API `v1` | GA 后至少 12 个月支持；弃用提前 6 个月公告并加 `Deprecation` / `Sunset` 头 |
| 客户端 ↔ 服务端 | 客户端支持向上兼容至少 2 个 minor 的服务端；服务端支持上一 minor 的客户端（MAJOR 除外） |
| Connector SDK 协议 | major 内字段只增不删 |
| 配置项 | 删除配置项需经历：默认保留 → 警告日志 → 下个 MAJOR 移除 |
| 数据库 | 支持从上一 MAJOR 的任一 GA 版本直接升级到当前 MAJOR 的最新版本 |
