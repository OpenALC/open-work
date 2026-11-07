# 变更日志

本项目的所有重要变更都会记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning 2.0.0](https://semver.org/lang/zh-CN/)。

产品版本、开放 API 版本、Connector SDK 协议版本与数据库迁移版本分别独立管理，
发布流程见 [docs/development/release.md](docs/development/release.md)。

变更类型：

- `Added` 新增功能
- `Changed` 行为变更
- `Deprecated` 即将移除
- `Removed` 已移除
- `Fixed` 缺陷修复
- `Security` 安全修复

---

## [Unreleased]

### Added

- 项目工程基线文档：里程碑与长任务规划、CI 流程、发版流程、审查流程
- 开源治理文件：README、CONTRIBUTING、AGENTS、SECURITY、CODE_OF_CONDUCT、LICENSE

---

<!--
发布时按以下格式追加：

## [1.2.0] - 2026-11-07

### Added
- feat(im): 部门群 (#123)

### Changed
- refactor(workflow): 调度器简化 (#130)

### Fixed
- fix(auth): 跨租户查询数据泄露 (#140)

### Security
- 升级 golang.org/x/net 至 0.31.0（CVE-XXXX-XXXX）

[Unreleased]: https://github.com/OpenALC/open-work/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/OpenALC/open-work/compare/v1.1.0...v1.2.0
-->
