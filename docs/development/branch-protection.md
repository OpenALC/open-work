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
| 2026-11-07 | 重建仓库基线 | 待配置（仓库刚初始化，尚无实际保护规则） |

> 配置完成后在此追加记录：日期、变更内容、执行人。

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
