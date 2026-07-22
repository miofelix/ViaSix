# ViaSix monorepo orchestrator.
# Platform-specific builds live under apps/*; this file only delegates.

MACOS_DIR := apps/macos
WINDOWS_DIR := apps/windows
ANDROID_DIR := apps/android
CONTRACTS_DIR := contracts

.PHONY: \
	help \
	macos-build \
	macos-test \
	macos-check \
	macos-app \
	macos-clean \
	windows-skeleton \
	android-skeleton \
	contracts-check \
	check \
	check-all

help:
	@echo "ViaSix monorepo targets:"
	@echo "  make macos-check       - lint, build, test macOS app"
	@echo "  make macos-app         - package ad-hoc ViaSix.app"
	@echo "  make macos-build       - swift build (macOS)"
	@echo "  make macos-test        - swift test (macOS)"
	@echo "  make macos-clean       - clean macOS build artifacts"
	@echo "  make contracts-check   - verify contracts layout and fixtures"
	@echo "  make windows-skeleton  - verify Windows placeholder tree"
	@echo "  make android-skeleton  - verify Android placeholder tree"
	@echo "  make check             - contracts + macOS check (default CI)"
	@echo "  make check-all         - check + platform skeletons"

macos-build:
	$(MAKE) -C $(MACOS_DIR) build

macos-test:
	$(MAKE) -C $(MACOS_DIR) test

macos-check:
	$(MAKE) -C $(MACOS_DIR) check

macos-app:
	$(MAKE) -C $(MACOS_DIR) app

macos-clean:
	$(MAKE) -C $(MACOS_DIR) clean

contracts-check:
	@test -f "$(CONTRACTS_DIR)/VERSION"
	@test -f "$(CONTRACTS_DIR)/schemas/local-proxy.schema.json"
	@test -f "$(CONTRACTS_DIR)/schemas/x-viasix.schema.json"
	@test -f "$(CONTRACTS_DIR)/fixtures/mihomo-config/rule-replace-server.in.yaml"
	@test -f "$(CONTRACTS_DIR)/fixtures/mihomo-config/rule-replace-server.out.yaml"
	@echo "contracts layout OK (version $$(cat "$(CONTRACTS_DIR)/VERSION"))"

windows-skeleton:
	@test -f "$(WINDOWS_DIR)/README.md"
	@test -f "$(WINDOWS_DIR)/scripts/fetch-mihomo.ps1"
	@test -d "$(WINDOWS_DIR)/src"
	@test -d "$(WINDOWS_DIR)/packaging"
	@echo "windows skeleton OK"

android-skeleton:
	@test -f "$(ANDROID_DIR)/README.md"
	@test -f "$(ANDROID_DIR)/settings.gradle.kts"
	@test -f "$(ANDROID_DIR)/app/src/main/AndroidManifest.xml"
	@test -f "$(ANDROID_DIR)/app/src/main/java/dev/viasix/app/Placeholder.kt"
	@echo "android skeleton OK"

check: contracts-check macos-check

check-all: check windows-skeleton android-skeleton
