# Homelab Helm OCI Management Makefile

HARBOR_URL ?= harbor.yuriy-lab.cloud
HARBOR_PROJECT ?= charts
OCI_REPO := oci://$(HARBOR_URL)/$(HARBOR_PROJECT)

# Find manifest directories that contain a Chart.yaml, excluding dependencies in 'charts/'
ifeq ($(APP),)
CHARTS := $(shell find kubernetes/apps -name "Chart.yaml" -not -path "*/charts/*" -exec dirname {} \;)
else
CHARTS := kubernetes/apps/$(APP)/manifest
endif

.PHONY: all help lint package push release login clean

help:
	@echo "Available targets:"
	@echo "  lint        - Run helm lint on charts"
	@echo "  package     - Package charts into .tgz"
	@echo "  push        - Push packaged charts to Harbor OCI registry"
	@echo "  release     - Lint, package, and push charts"
	@echo "  login       - Login to Harbor registry (requires HARBOR_USER and HARBOR_PASSWORD)"
	@echo ""
	@echo "Usage:"
	@echo "  make release APP=whoami   # Target a specific app"
	@echo "  make release              # Target all apps (bulk)"

lint:
	@for chart in $(CHARTS); do \
		if [ -d "$$chart" ]; then \
			echo "Linting $$chart..."; \
			helm lint $$chart; \
		else \
			echo "Error: Directory $$chart not found."; exit 1; \
		fi; \
	done

package:
	@mkdir -p .build
	@for chart in $(CHARTS); do \
		if [ -d "$$chart" ]; then \
			echo "Cleaning dependencies for $$chart..."; \
			rm -rf $$chart/charts $$chart/Chart.lock; \
			if grep -q "dependencies:" $$chart/Chart.yaml; then \
				echo "Building dependencies for $$chart..."; \
				helm dependency build $$chart; \
			else \
				echo "No dependencies defined for $$chart."; \
			fi; \
			echo "Packaging $$chart..."; \
			helm package $$chart -d .build; \
		else \
			echo "Error: Directory $$chart not found."; exit 1; \
		fi; \
	done

push: package
	@if [ -n "$(APP)" ]; then \
		CHART_NAME=$$(grep '^name:' kubernetes/apps/$(APP)/manifest/Chart.yaml | awk '{print $$2}'); \
		CHART_VER=$$(grep '^version:' kubernetes/apps/$(APP)/manifest/Chart.yaml | awk '{print $$2}'); \
		PKG=".build/$$CHART_NAME-$$CHART_VER.tgz"; \
		echo "Pushing $$PKG to $(OCI_REPO)..."; \
		helm push $$PKG $(OCI_REPO); \
	else \
		for pkg in .build/*-yk-*.tgz; do \
			echo "Pushing $$pkg to $(OCI_REPO)..."; \
			helm push $$pkg $(OCI_REPO); \
		done; \
	fi

release: lint push
	@echo "Charts released to $(OCI_REPO)"

login:
	@echo "Logging in to $(HARBOR_URL)..."
	@echo $(HARBOR_PASSWORD) | helm registry login $(HARBOR_URL) --username $(HARBOR_USER) --password-stdin

clean:
	rm -rf .build
