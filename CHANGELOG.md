# 变更日志

本项目的所有重要变更都会记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

版本号格式 `0.MINOR.PATCH`：第一段固定为 `0`；日常只递增第三段（功能实现与缺陷修复都算），只有破坏性变更或里程碑收口才递增第二段。两段均为十进制、不设上限。详见 [docs/development/release.md](docs/development/release.md)。

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
发布时按以下格式追加。纯修复版本在标题后加「(仅修复)」，便于私有化部署判断能否直接升级。

## [0.5.2] (仅修复) - 2026-11-07

### Fixed
- fix(auth): 跨租户查询数据泄露 (#140)

### Security
- 升级 golang.org/x/net 至 0.31.0（CVE-XXXX-XXXX）

## [0.5.1] - 2026-11-06

### Added
- feat(im): 部门群 (#123)

### Changed
- refactor(workflow): 调度器简化 (#130)

[Unreleased]: https://github.com/OpenALC/open-work/compare/v0.5.2...HEAD
[0.5.2]: https://github.com/OpenALC/open-work/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/OpenALC/open-work/compare/v0.5.0...v0.5.1
-->
