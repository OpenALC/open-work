# 本地环境搭建

> 状态：本文为 M0 / L0.1 的交付物之一，随仓库骨架落地逐步补全命令细节。
> 当前仓库仅有文档与流程配置，`make` 目标已定义但对应代码尚未生成。

---

## 一、依赖

| 工具 | 版本 | 用途 |
|---|---|---|
| Go | 1.25+ | 后端 |
| Node.js | 24 LTS | Web |
| pnpm | 10+ | Web 包管理 |
| Flutter | 3.35+ | 客户端（可选） |
| Docker + Compose v2 | 最新稳定版 | 本地 MySQL / Redis / 端到端 |
| golangci-lint | 见 `.golangci.yml` | Go 静态检查 |
| gitleaks | 8.21+ | 密钥扫描 |

Windows 用户建议在 WSL2 或 Git Bash 中执行 `make` 目标；本仓库的 `Makefile` 使用 POSIX shell。

---

## 二、初始化

```bash
git clone https://github.com/OpenALC/open-work.git
cd open-work

cp .env.example .env      # 按需修改；.env 不会被提交
make bootstrap            # 拉依赖、生成 sqlc 与契约代码
```

`make bootstrap` 当前会跳过尚未存在的生成步骤，M0 落地后自动生效。

---

## 三、启动

```bash
make dev-up    # MySQL 8.4 + Redis 7 + 三进程
make logs      # 跟随日志
make dev-down  # 停止
make dev-reset # 停止并清空数据卷
```

验证：

```bash
curl -fsS http://localhost:8080/healthz
curl -fsS http://localhost:8080/readyz
```

---

## 四、常用命令

| 命令 | 说明 |
|---|---|
| `make test` | 单元测试 |
| `make test-integration` | 集成测试（需要真实 MySQL + Redis） |
| `make test-cover` | 覆盖率报告到 `coverage.html` |
| `make ci` | 与 CI 等价的全部门禁 |
| `make migrate-up` / `make migrate-down` | 迁移 |
| `make migrate-create name=add_xxx` | 新建迁移 |
| `make sqlc` | 重新生成数据访问代码 |
| `make openapi-gen` | 重新生成契约类型与客户端 |
| `make seed` | 导入演示数据 |

---

## 五、故障排查

| 现象 | 处理 |
|---|---|
| `readyz` 返回 503 | 检查 MySQL / Redis 是否就绪：`docker compose -f deploy/compose/docker-compose.dev.yml ps` |
| 迁移失败 | 确认 `.env` 中 `OPENWORK_DB_DSN` 的库名与 compose 中一致；`make dev-reset` 后重试 |
| `make` 目标报 `command not found` | 缺少对应工具，执行 `make tools` 或参考 §一 |
| 端口冲突 | 修改 `.env` 中 `OPENWORK_HTTP_ADDR` / `OPENWORK_REALTIME_ADDR`，同步修改 compose 端口映射 |
| Windows 下换行导致脚本失败 | 确认 `core.autocrlf=false`（仓库已通过 `.gitattributes` 固定为 LF） |
