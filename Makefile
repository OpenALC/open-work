# OpenWork 开发与构建入口
#
# 所有 CI job 都有对应的 make 目标，本地 `make ci` 与 CI 等价。
# 完整说明见 docs/development/ci.md。

SHELL := /bin/sh
.DEFAULT_GOAL := help

# ─── 变量 ────────────────────────────────────────────────────────
VERSION      ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT       ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
BUILD_TIME   ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

GO           ?= go
GO_VERSION   ?= 1.25
PNPM         ?= pnpm
NODE_VERSION ?= 24
FLUTTER      ?= flutter

LDFLAGS := -s -w \
	-X main.version=$(VERSION) \
	-X main.commit=$(COMMIT) \
	-X main.buildTime=$(BUILD_TIME)

SERVICES := server realtime worker
DB_DSN   ?= $(OPENWORK_DB_DSN)

COMPOSE_DEV := deploy/compose/docker-compose.dev.yml
COMPOSE_E2E := deploy/compose/docker-compose.e2e.yml

SQLC_VERSION    := v1.27.0
MIGRATE_VERSION := v4.18.1

.PHONY: help
help: ## 显示可用目标
	@printf "OpenWork — 可用目标：\n\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*?##/ {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ─── 环境准备 ────────────────────────────────────────────────────
.PHONY: bootstrap
bootstrap: ## 安装依赖、生成代码、创建本地配置
	$(GO) mod download
	$(PNPM) install --frozen-lockfile
	@[ -f .env ] || cp .env.example .env && echo "已创建 .env，请按需修改"
	@if [ -f apps/flutter/pubspec.yaml ]; then cd apps/flutter && $(FLUTTER) pub get; fi
	@$(MAKE) sqlc || true
	@$(MAKE) openapi-gen || true

.PHONY: tools
tools: ## 安装开发工具
	$(GO) install github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)
	$(GO) install github.com/golang-migrate/migrate/v4/cmd/migrate@$(MIGRATE_VERSION)
	$(GO) install golang.org/x/vuln/cmd/govulncheck@latest

# ─── 本地运行 ────────────────────────────────────────────────────
.PHONY: dev-up
dev-up: ## 启动本地开发栈（MySQL + Redis + 三进程）
	docker compose -f $(COMPOSE_DEV) up -d --wait --wait-timeout 180

.PHONY: dev-down
dev-down: ## 停止本地开发栈
	docker compose -f $(COMPOSE_DEV) down

.PHONY: dev-reset
dev-reset: ## 停止并清空本地数据卷
	docker compose -f $(COMPOSE_DEV) down -v

.PHONY: logs
logs: ## 跟随本地栈日志
	docker compose -f $(COMPOSE_DEV) logs -f --tail=100

.PHONY: run
run: ## 本地直接运行三个进程（不使用容器）
	$(GO) run ./cmd/openwork-server

# ─── 构建 ────────────────────────────────────────────────────────
.PHONY: build
build: ## 构建三个进程到 bin/
	@mkdir -p bin
	@for svc in $(SERVICES); do \
		echo "building openwork-$$svc"; \
		$(GO) build -trimpath -ldflags "$(LDFLAGS)" -o bin/openwork-$$svc ./cmd/openwork-$$svc; \
	done

.PHONY: build-linux
build-linux: ## 交叉编译 linux/amd64 与 linux/arm64
	@mkdir -p dist
	@for svc in $(SERVICES); do \
		for arch in amd64 arm64; do \
			echo "building openwork-$$svc linux/$$arch"; \
			GOOS=linux GOARCH=$$arch CGO_ENABLED=0 \
				$(GO) build -trimpath -ldflags "$(LDFLAGS)" \
				-o dist/openwork-$$svc_$(VERSION)_linux_$$arch ./cmd/openwork-$$svc; \
		done; \
	done

.PHONY: clean
clean: ## 清理构建产物
	rm -rf bin dist coverage.out coverage.html
	@if [ -f apps/web/package.json ]; then rm -rf apps/web/dist; fi

# ─── 代码生成 ────────────────────────────────────────────────────
.PHONY: sqlc
sqlc: ## 重新生成数据访问代码
	$(GO) run github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION) generate

.PHONY: openapi-gen
openapi-gen: ## 从 OpenAPI 重新生成服务端类型与 TS 客户端
	@if [ ! -f docs/api/openapi.yaml ]; then echo "docs/api/openapi.yaml 尚未建立，跳过"; exit 0; fi
	$(GO) run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 \
		-config docs/api/oapi-codegen.yaml docs/api/openapi.yaml
	@if [ -f apps/web/package.json ]; then \
		$(PNPM) --filter @openwork/contracts run generate; \
	fi

# ─── 数据库 ──────────────────────────────────────────────────────
.PHONY: migrate-up
migrate-up: ## 执行全部迁移
	$(GO) run github.com/golang-migrate/migrate/v4/cmd/migrate@$(MIGRATE_VERSION) \
		-path database/migrations/mysql -database "$(DB_DSN)" up

.PHONY: migrate-down
migrate-down: ## 回滚一步迁移
	$(GO) run github.com/golang-migrate/migrate/v4/cmd/migrate@$(MIGRATE_VERSION) \
		-path database/migrations/mysql -database "$(DB_DSN)" down 1

.PHONY: migrate-create
migrate-create: ## 新建迁移：make migrate-create name=add_xxx
	@test -n "$(name)" || { echo "用法: make migrate-create name=<snake_case>"; exit 1; }
	$(GO) run github.com/golang-migrate/migrate/v4/cmd/migrate@$(MIGRATE_VERSION) \
		create -ext sql -dir database/migrations/mysql -seq $(name)

.PHONY: seed
seed: ## 导入演示数据
	docker compose -f $(COMPOSE_DEV) exec -T mysql \
		mysql -uroot -proot openwork < database/seeds/dev.sql

# ─── 测试 ────────────────────────────────────────────────────────
.PHONY: test
test: ## 单元测试
	$(GO) test -race -shuffle=on ./...

.PHONY: test-integration
test-integration: ## 集成测试（需要真实 MySQL + Redis）
	$(GO) test -tags=integration -race -shuffle=on -timeout=20m ./...

.PHONY: test-cover
test-cover: ## 单元测试并生成覆盖率报告
	$(GO) test -race -shuffle=on -coverprofile=coverage.out -covermode=atomic ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "覆盖率报告：coverage.html"

.PHONY: bench-check
bench-check: ## 基准测试与基线对比
	$(GO) test -run '^$$' -bench . -benchmem ./... | tee bench.txt

.PHONY: db-compat-check
db-compat-check: ## 迁移在空库与历史快照上各跑一遍
	@echo "TODO: M0/L0.3 落地后实现（空库 + 历史 schema 快照）"

.PHONY: e2e
e2e: ## 端到端测试（需要已启动的 e2e 栈）
	$(PNPM) --filter @openwork/web run e2e

# ─── 质量检查 ────────────────────────────────────────────────────
.PHONY: fmt
fmt: ## 格式化 Go 代码
	gofmt -w .

.PHONY: fmt-check
fmt-check: ## 检查 Go 格式
	@test -z "$$(gofmt -l .)" || { echo "以下文件格式不合规："; gofmt -l .; exit 1; }

.PHONY: vet
vet: ## go vet
	$(GO) vet ./...

.PHONY: lint
lint: ## golangci-lint
	golangci-lint run --timeout=10m

.PHONY: web-install
web-install: ## 安装前端依赖
	$(PNPM) install --frozen-lockfile

.PHONY: web-lint
web-lint: ## 前端 lint
	$(PNPM) -r --if-present run lint

.PHONY: web-typecheck
web-typecheck: ## 前端类型检查
	$(PNPM) -r --if-present run typecheck

.PHONY: web-build
web-build: ## 前端构建
	$(PNPM) -r --if-present run build

.PHONY: web-test
web-test: ## 前端测试
	$(PNPM) -r --if-present run test

.PHONY: flutter-analyze
flutter-analyze: ## Flutter 静态分析
	@if [ -f apps/flutter/pubspec.yaml ]; then \
		cd apps/flutter && $(FLUTTER) analyze --fatal-infos --fatal-warnings; \
	fi

.PHONY: flutter-test
flutter-test: ## Flutter 测试
	@if [ -f apps/flutter/pubspec.yaml ]; then \
		cd apps/flutter && $(FLUTTER) test --coverage; \
	fi

.PHONY: openapi-lint
openapi-lint: ## OpenAPI 规范检查
	@if [ -f docs/api/openapi.yaml ]; then \
		$(PNPM) dlx @redocly/cli@1 lint docs/api/openapi.yaml; \
	fi

# ─── 安全 ────────────────────────────────────────────────────────
.PHONY: vuln
vuln: ## 依赖漏洞扫描
	$(GO) run golang.org/x/vuln/cmd/govulncheck@latest ./...

.PHONY: secrets
secrets: ## 密钥泄露扫描
	gitleaks detect --source . --redact --no-banner

# ─── 聚合目标 ────────────────────────────────────────────────────
.PHONY: ci
ci: fmt-check vet lint build test ci-web ci-contract ## 与 CI 等价的全部门禁（不含集成测试）
	@echo "✓ make ci 通过"

.PHONY: ci-full
ci-full: ci test-integration ## 全量：含集成测试
	@echo "✓ make ci-full 通过"

.PHONY: ci-web
ci-web: web-install web-lint web-typecheck web-build web-test flutter-analyze flutter-test ## 前端与客户端检查
	@echo "✓ make ci-web 通过"

.PHONY: ci-contract
ci-contract: openapi-lint ## 契约与迁移检查
	@echo "✓ make ci-contract 通过"

.PHONY: ci-security
ci-security: vuln secrets ## 安全扫描
	@echo "✓ make ci-security 通过"
