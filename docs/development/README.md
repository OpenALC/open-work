# 开发文档索引

本目录是 OpenWork 的**工程流程权威来源**。产品或架构层面请见 [`docs/product/`](../product) 与 [`docs/architecture/`](../architecture)。

---

## 核心流程

| 文档 | 内容 | 何时读 |
|---|---|---|
| [roadmap.md](roadmap.md) | 里程碑划分、长任务（LT）与小任务（ST）定义、长任务内无阻塞点机制、DoD、并行轨道、风险 | 每次领取任务前 |
| [ci.md](ci.md) | 流水线分类、job 清单、路径过滤、缓存、分支保护、CI 异常处理 | 提交代码前、CI 失败时 |
| [release.md](release.md) | 版本体系、分支与标签、发布检查清单、发版执行、迁移策略、回滚、供应链 | 发版时 |
| [review.md](review.md) | 六层审查模型、自我审查清单、自动审查规则、交叉审查输出格式、抽检与里程碑审查 | 提交 PR 前、审查他人时 |

## 支撑文档

| 文档 | 内容 |
|---|---|
| [known-issues.md](known-issues.md) | 执行期发现但不在当前长任务范围内处理的问题 |
| [getting-started.md](getting-started.md) | 本地环境搭建（M0/L0.1 交付） |
| [branch-protection.md](branch-protection.md) | `main` 分支保护规则的实际配置记录（M0/L0.2 交付） |
| [compatibility.md](compatibility.md) | 版本兼容性矩阵（M5 交付） |
| [reviews/](reviews/) | 里程碑审查报告 `m<N>-review.md` |
| [incidents/](incidents/) | 事故复盘 `YYYY-MM-DD-<slug>.md` |

---

## 相关文档

| 文档 | 内容 |
|---|---|
| [../../AGENTS.md](../../AGENTS.md) | 技术基线与 AI 开发作业手册 |
| [../../CONTRIBUTING.md](../../CONTRIBUTING.md) | 贡献指南 |
| [../../SECURITY.md](../../SECURITY.md) | 安全策略与漏洞报告 |
| [../adr/](../adr/) | 架构决策记录 |
| [../需求文档.md](../需求文档.md) | 产品需求与技术方案 |

---

## 文档维护规则

1. **流程变更必须同时改文档与实现。** 改了 `.github/workflows/` 就要改 `ci.md`；改了发版脚本就要改 `release.md`。
2. **文档里的命令必须可执行。** 引用 `make` 目标前确认它存在。
3. **不写"应该"。** 写"是什么、怎么做、怎么检查"。
4. **决策写进 ADR，流程写进本目录。** 不要混。
5. **过期文档删除，不保留"历史版本"**，历史在 git 里。
