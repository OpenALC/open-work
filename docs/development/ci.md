# CI

> 关联：[里程碑](roadmap.md) · [发版](release.md) · [审查](review.md)

两条流水线：`ci.yml`（PR 与 push main）和 `release.yml`（打 tag）。没有别的。

---

## 一、`ci.yml`

触发：PR 到 `main`、push 到 `main`。

### 判断先行

仓库骨架（`go.mod`、`apps/web/package.json`、`apps/flutter/pubspec.yaml`）还不存在时，对应 job 直接跳过，不报红。M0 落地后自动生效。

### 检查项

| Job | 内容 |
|---|---|
| `commit-lint` | Conventional Commits |
| `secrets-scan` | gitleaks |
| `go` | `gofmt` / `go vet` / `go build` / `go test -race` |
| `go-integration` | MySQL 8.4 + Redis 7 服务容器，`-tags=integration` |
| `web` | `eslint` / `vue-tsc` / `vite build` / `vitest` |
| `flutter` | `flutter analyze` / `dart format` / `flutter test` |
| `migration` | 迁移文件名连续、`up → down → up` 可重复 |
| `build-image` | 三进程镜像能构建（不推送） |

全部通过才合并。

### 路径过滤

只改文档不跑代码检查；只改 `apps/web` 不跑 Go。省时间，也省额度。

### 缓存

Go modules、pnpm store、Flutter SDK、Docker layer。键用锁文件哈希。

---

## 二、`release.yml`

触发：push tag `v*`。

1. 校验 tag 在 `main` 的可达历史中、`CHANGELOG.md` 有对应段落
2. 跑一遍 `ci.yml` 的全部检查
3. 交叉编译三进程（linux/darwin/windows × amd64/arm64）
4. 构建并推送镜像 `ghcr.io/openalc/open-work-{server,realtime,worker}`，打版本 tag 与 major.minor tag
5. 创建 GitHub Release（草稿）

详见 [release.md](release.md)。

---

## 三、本地

```bash
make ci            # 门禁 + 单元测试 + 构建
make ci-full       # 含集成测试
make fmt vet lint test build
```

`make ci` 与 CI 的差别只有：不上传覆盖率、不推镜像。

---

## 四、CI 挂了怎么办

| 情况 | 处理 |
|---|---|
| 代码问题 | 修 |
| 检查本身误报 | 修检查 |
| runner / 缓存 / 服务容器抽风 | 重跑。同一个 job 重跑两次还在非代码环节挂，记进 issue |
| 太慢 | 先加缓存，再并行拆 job。不砍检查项 |

不允许为了让 CI 变绿去删测试、放宽断言、加 skip。

---

## 五、分支策略

**不使用 GitHub 分支保护。**

原因：单人项目，GitHub 不允许批准自己的 PR，强制审批等于把 `main` 锁死；骨架未落地时 required checks 不会上报，会被判定 pending 永久阻塞。

替代做法：

- 小改动可以直接推 `main`，但推之前本地 `make ci` 要通过
- 跨模块、涉及迁移/权限/认证的改动走 PR，CI 全绿再合
- 合并只用 Squash（仓库设置已强制，merge commit 与 rebase 都关了）
- 不 force push 已经推出去的 `main`

等到有第二个有写权限的维护者、且 M0 骨架落地后再考虑启用保护。
