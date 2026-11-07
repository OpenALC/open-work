# OpenWork

> 轻量、开源、可扩展的企业协作与管理平台

OpenWork 是一个以**组织和身份**为基础，以 **IM、OA 审批、考勤**为核心，以 **开放 API、连接器、WebView** 为扩展机制的现代化企业协作平台。

它不试图复制大型商业办公套件的全部功能，而是坚持轻量化核心、标准化接口、模块化实现，并支持企业完全私有化部署。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Go](https://img.shields.io/badge/Go-1.25-00ADD8?logo=go)](#技术栈)
[![Vue](https://img.shields.io/badge/Vue-3-42b883?logo=vuedotjs)](#技术栈)
[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter)](#技术栈)

---

## 状态

**Pre-alpha / 工程基线阶段。** 仓库正在搭建骨架，尚未发布可用版本。里程碑与计划见 [docs/development/roadmap.md](docs/development/roadmap.md)。

## 能力规划

| 模块 | 内容 |
|---|---|
| 身份与组织 | 统一账号、多企业身份、无限级部门树、组织历史、扫码登录 |
| 权限 | RBAC + 数据范围 + 企业策略，菜单/页面/按钮/API/数据粒度 |
| IM | 单聊、群聊、部门自动群、多端同步、离线补拉、消息卡片 |
| OA 审批 | 可视化流程设计器、会签/或签/抄送/条件分支、外部 API 节点 |
| 考勤 | GPS / Wi-Fi / 人脸 / 考勤机打卡、排班轮班、假期额度、工时报表 |
| 开放平台 | OpenAPI 3.1、应用与凭据、连接器、Webhook、WebView 容器与 JS SDK |
| 客户端 | Web（Vue 3）、Android / iOS / Windows / macOS / Linux（Flutter） |

不内置 ERP、CRM、MES、WMS、财务等业务系统——这些通过应用、连接器和开放 API 集成。

## 技术栈

| 领域 | 技术 |
|---|---|
| 后端 | Go · Gin · sqlc · `database/sql` |
| 数据 | MySQL 8.4 LTS · Redis · Transactional Outbox |
| 实时 | WebSocket（独立 `openwork-realtime` 进程） |
| 前端 | Vue 3 · TypeScript · Vite · Pinia · Naive UI |
| 跨端 | Flutter |
| 契约 | OpenAPI 3.1 |
| 部署 | Docker Compose · GitHub Actions |

架构为**模块化单体 + 独立实时网关 + 异步 Worker**，三个进程共享同一套 Go 领域代码：

```text
openwork-server    HTTP API / 身份 / 组织 / 权限 / OA / 考勤 / 应用平台
openwork-realtime  WebSocket / 在线状态 / 实时投递
openwork-worker    Outbox 派发 / 工作流调度 / Webhook / 考勤计算 / 通知
```

## 快速开始

> 开发环境需要：Go 1.25+、Node 24 + pnpm 10、Docker。

```bash
git clone https://github.com/OpenALC/open-work.git
cd open-work
make bootstrap          # 安装依赖、生成代码、创建本地配置
make dev-up             # 启动 MySQL + Redis + 三进程
```

服务启动后：

- API：<http://localhost:8080>
- 健康检查：<http://localhost:8080/healthz>

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 仓库结构

```text
cmd/            三个可执行进程入口
internal/       业务模块（iam / organization / authorization / im /
                workflow / attendance / announcement / bot / platform /
                infrastructure）
apps/           web（Vue）、flutter（多端）
packages/       contracts、connector-sdk、design-tokens
database/       migrations、queries、seeds
deploy/         compose 与 Dockerfile
docs/           产品、架构、ADR、API、开发流程
```

## 参与贡献

- 先读 [CONTRIBUTING.md](CONTRIBUTING.md)
- 开发流程与 AI 协作约定见 [AGENTS.md](AGENTS.md)
- 里程碑与任务粒度见 [docs/development/roadmap.md](docs/development/roadmap.md)
- CI、发版、审查流程见 [docs/development/](docs/development/)

提交遵循 [Conventional Commits](https://www.conventionalcommits.org/)，分支采用 Trunk-Based Development。

## 安全

安全问题请**不要**公开提 issue，按 [SECURITY.md](SECURITY.md) 私下报告。

## 许可证

[Apache License 2.0](LICENSE)。允许商业使用、私有化部署与二次开发。
