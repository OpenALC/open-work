# 发版

> 关联：[里程碑](roadmap.md) · [CI](ci.md) · [审查](review.md)

---

## 一、版本号

SemVer：`MAJOR.MINOR.PATCH`，预发布加 `-alpha.N` / `-beta.N` / `-rc.N`。

| 变更 | 递增 |
|---|---|
| 破坏性 API、不兼容数据库变更、要人工介入的升级步骤 | MAJOR |
| 新功能、新端点、新模块 | MINOR |
| 修 bug、性能、文档 | PATCH |

产品版本、API 版本（`/api/v1`）、Connector SDK 协议版本、数据库迁移版本**各自独立**，不互相绑定。

---

## 二、发一版

```bash
git switch main && git pull --ff-only
git switch -c chore/release-v1.2.0
```

1. `CHANGELOG.md`：把 `Unreleased` 改成 `## [1.2.0] - YYYY-MM-DD`
2. `docs/api/openapi.yaml` 的 `info.version` 同步
3. 提交 `chore(release): v1.2.0`，合入 `main`

然后打标签：

```bash
git switch main && git pull --ff-only
git tag -s v1.2.0 -m "v1.2.0"
git push origin v1.2.0
```

`release.yml` 自动跑，不需要手动传制品。

---

## 三、发之前看一遍

- [ ] `main` 的 CI 绿
- [ ] `CHANGELOG.md` 有本版本段落，条目和提交类型对得上
- [ ] OpenAPI 相对上一版没有非预期破坏性变更（有的话在 Breaking Changes 里写明）
- [ ] 迁移在空库能跑通
- [ ] 从上一版升级演练过一遍
- [ ] `govulncheck` / `pnpm audit` 没有 high 以上
- [ ] 上一版能用的客户端连新服务端没问题

---

## 四、数据库变更

用 expand / contract，让新旧版本能同时跑：

| 阶段 | 做什么 |
|---|---|
| 本次发布 | 加列加表、双写、回填 |
| 下次发布 | 读路径切到新结构 |
| 再下次 | 删旧列 |

规矩：

- 一次发布不删上一版还在用的列或表
- 大表加索引用 online DDL，回填分批
- 迁移只能从 `openwork-server migrate` 执行，不在启动时隐式执行
- 已合并的迁移文件不再修改

---

## 五、出问题怎么退

| 情况 | 做法 | 时间 |
|---|---|---|
| 应用 bug，数据没问题 | 镜像 tag 退回上一版 | 10 分钟内 |
| 迁移有问题 | 执行 down 迁移；不可逆的走备份恢复 | 1 小时内 |
| 客户端有问题 | 服务端兼容旧客户端，或用开关降级 | 30 分钟内 |
| 安全漏洞 | 见第六节 | 立即 |

触发回滚：错误率超 5% 持续 5 分钟、核心功能不可用、数据不一致、越权。

回滚完写一份复盘，放 `docs/postmortems/YYYY-MM-DD-<slug>.md`。

---

## 六、安全补丁

1. 修复合入 `main`，打 patch tag
2. 立即推送镜像
3. 发 GitHub Security Advisory：受影响版本、修复版本、缓解措施
4. 严重问题目标 24 小时出修复版

---

## 七、制品

| 制品 | 位置 |
|---|---|
| 镜像 | `ghcr.io/openalc/open-work-{server,realtime,worker}` |
| 二进制 | Release assets，六种平台 |
| 私有化包 | `openwork-<version>-compose.tar.gz` |
| 客户端 | Release assets + 应用商店 |
| 校验 | `SHA256SUMS` |

`latest` 只指向最新正式版，预发布不打。

---

## 八、兼容承诺

| 对象 | 承诺 |
|---|---|
| 开放 API `v1` | GA 后至少支持 12 个月，弃用提前 6 个月公告 |
| 客户端 ↔ 服务端 | 客户端至少兼容前 2 个 minor 的服务端 |
| Connector SDK | major 内字段只增不删 |
| 配置项 | 删之前先保留并打警告日志，下个 MAJOR 再删 |
