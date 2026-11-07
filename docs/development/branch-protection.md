# `main` 分支策略

> **当前状态：不使用 GitHub 分支保护。** `main` 上没有任何平台强制的检查、审批或推送限制。
>
> 本文件记录原因、替代约束，以及未来重新启用时的配置表。

---

## 一、当前做法

| 项 | 状态 |
|---|---|
| GitHub 分支保护规则 | **未启用**（已确认 `GET /branches/main/protection` 返回 `Branch not protected`） |
| 直接 push `main` | 允许 |
| 必须通过 PR | 不强制 |
| 必需审批 | 无 |
| 必需状态检查 | 无 |
| Force push | 不强制禁止（但仍不建议，见 §三） |
| 合并方式 | 仓库设置已强制 **Squash Merge only**（`allow_merge_commit` / `allow_rebase_merge` 均为 false） |

验证：

```bash
gh api repos/OpenALC/open-work/branches/main/protection
# 期望：404 Branch not protected
```

---

## 二、为什么不用

| 原因 | 说明 |
|---|---|
| 单人维护 | GitHub 不允许批准自己创建的 PR。强制 1 个审批会让 `main` 永久无法合并——这正是 2026-11-07 首次配置时实际遇到的情况 |
| required checks 尚不可靠 | 骨架文件（`go.mod`、`apps/web/package.json`、`apps/flutter/pubspec.yaml`）落地前，对应 job 通过路径过滤被跳过，不会上报状态。未上报的 required check 会被判为 pending，从而永久阻塞 |
| 流程仍在演进 | 早期频繁调整 CI 与目录结构，硬门禁的维护成本高于收益 |

---

## 三、替代约束（靠流程，不靠平台）

以下仍然必须遵守，由 [review.md](review.md) 的自我审查条目与交叉审查约束：

| 约束 | 要求 |
|---|---|
| 本地 `make ci` | 每次推送 `main` 前必须通过 |
| 小改动直推 | 允许，但仅限文档、配置、单文件修复 |
| 跨模块 / 涉及迁移 / 权限 / 认证 / 凭据 | 走 PR，CI 全绿后合并 |
| 不 force push 已推送的 `main` | 会改写历史，导致他人本地分叉与 CI 缓存失效 |
| 线性历史 | 使用 Squash Merge（仓库设置已强制） |

判断标准：**如果这次改动的回滚需要超过一次 `git revert`，就走 PR。**

---

## 四、重新启用的触发条件

满足**全部**条件后重新评估：

1. 至少有 2 名具有写权限的维护者（解决自批问题）
2. M0 骨架落地，`go-*` / `web-*` / `flutter-*` / `openapi-*` / `docker-*` 各组检查能稳定上报
3. 近 30 天 `pr.yml` 的基础设施失败率 ≤ 10%

---

## 五、启用时的目标配置

分两步：先只锁最基本的，稳定后再加。

### 第一阶段（骨架落地后）

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["commit-lint", "secrets-scan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
```

### 第二阶段（各组检查稳定上报后）

在第一阶段基础上，把 required contexts 扩充为：

```text
commit-lint
secrets-scan
go-fmt
go-vet
go-lint
go-test
go-integration
tenant-scope
web-lint
web-typecheck
web-build
web-test
flutter-analyze
flutter-test
openapi-lint
openapi-breaking
migration-check
security-govulncheck
security-license
docker-build
```

发布分支相关 PR（`chore/release-v*`）要求 2 个审批。

---

## 六、验证方式

启用后逐项验证：

```bash
# 应失败：直接 push main
git switch main && git commit --allow-empty -m "chore: test" && git push origin main

# 应失败：force push
git push --force origin main

# 应失败：未经审批合并
gh pr merge <num> --admin

# 应成功：走 PR + 审批 + 检查通过
```

每次变更在此追加记录：日期、变更内容、执行人、四项验证结果。

---

## 七、变更记录

| 日期 | 操作 | 结果 |
|---|---|---|
| 2026-11-07 | 重建仓库并首次配置分支保护（审批 1，必需检查 2 项） | 已生效，但导致无法自批合并 |
| 2026-11-07 | 审批数降为 0 | 可合并，但管理员仍受其他约束 |
| 2026-11-07 | **按维护者决定移除全部分支保护** | `GET /branches/main/protection` → 404 |
