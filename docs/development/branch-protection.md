# `main` 分支保护规则

> 本文件记录**实际生效**的配置，不是愿望清单。每次调整分支保护后同步更新本文。
>
> 配置方式：GitHub → Settings → Rules → Rulesets（或 Branches → Branch protection rules）。

---

## 一、目标配置

| 项 | 值 |
|---|---|
| 适用分支 | `main` |
| 直接 push | 禁止 |
| Force push | 禁止 |
| 删除分支 | 禁止 |
| 必须通过 PR | 是 |
| 必需审批数 | 1（`release/*` 相关为 2） |
| 审批后新提交需重新审批 | 是（dismiss stale approvals） |
| 必须与 `main` 同步 | 是（require branches up to date） |
| 合并方式 | 仅 Squash merge |
| 线性历史 | 是 |
| 管理员受约束 | 是（Do not allow bypassing） |
| 未解决对话 | 必须全部解决 |

---

## 二、必需状态检查

以下 job 名称必须出现在 required status checks 中：

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

骨架阶段说明：`go-*` / `web-*` / `flutter-*` / `openapi-*` / `docker-*` 这几组在有对应骨架文件前不会触发，GitHub 会对未触发的 required check 判为 pending。M0 落地前，先只勾选 `commit-lint` 与 `secrets-scan`，其余在对应骨架合入后逐项加入。

---

## 三、当前实际状态

| 日期 | 操作 | 结果 |
|---|---|---|
| 2026-11-07 | 仓库重建，首次配置分支保护 | 已生效（详见下方实际配置） |

### 2026-11-07 实际生效配置

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
    "required_approving_review_count": 0
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
```

**与目标配置的偏差（已知并接受）：**

| 项 | 目标 | 实际 | 原因 |
|---|---|---|---|
| 必需审批数 | 1–2 | 0 | 当前为单人维护阶段，GitHub 不允许批准自己创建的 PR。若设为 1，`main` 将永久无法合并 |
| 必需状态检查 | 见 §二 | 仅 `commit-lint`、`secrets-scan` | 其余检查在骨架文件落地前不会触发，未触发的 required check 会被判为 pending 从而永久阻塞 |

**恢复完整保护的触发条件：**

1. 至少 2 名具有写权限的维护者 → 把 `required_approving_review_count` 调整为 1（`release/*` 相关为 2）
2. 对应骨架合入（M0 完成）→ 按 §二 逐项加入 required status checks

每次调整后更新本表，并执行 §四 的四项验证。

---

## 四、验证方式

```bash
# 应失败：直接 push main
git switch main && git commit --allow-empty -m "chore: test" && git push origin main

# 应失败：force push
git push --force origin main

# 应失败：未经审批合并
gh pr merge <num> --admin

# 应成功：走 PR + 审批 + 检查通过
```

每次调整后执行上述四项验证并记录结果。
