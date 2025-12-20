# Makefile for building Proxmox VE kernel packages in a Docker build environment (Docker Desktop safe)
# Key idea: build on a Docker volume (Linux FS), export artifacts to a bind-mounted ./build directory.

SHELL := /bin/bash

# Variables
IMAGE_NAME   := pve-kernel-builder
CONTAINER_NAME := pve-kernel-builder
PWD          := $(shell pwd)
OUTDIR       := $(PWD)/output
VOLUME_NAME  := pve-kernel-src

# Where the repo lives inside the container
SRC_MNT      := /src

.PHONY: help build-container build \
        volume-create volume-rm volume-shell volume-init \
        run-container run \
        prep-source prep \
        kernel rebuild-kernel \
        export-debs all \
        clean clean-all all-clean

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN { FS=":.*##" } \
		/^[a-zA-Z0-9_.-]+:.*##/ { \
			printf "  %-20s %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)

build-container: ## Build the Docker image (linux/amd64) with all build tools
	docker buildx build --platform linux/amd64 -f Dockerfile -t $(IMAGE_NAME) .

build: build-container ## -- Alias for build-container

volume-create: ## Create the docker volume used for source + build (safe on Docker Desktop)
	@docker volume inspect $(VOLUME_NAME) >/dev/null 2>&1 || docker volume create $(VOLUME_NAME) >/dev/null

volume-rm: ## Remove the docker volume (DESTROYS source/build state)
	docker volume rm -f $(VOLUME_NAME) >/dev/null 2>&1 || true

volume-shell: build-container volume-create ## Open a bash shell with the volume mounted at /src
	docker run --name $(CONTAINER_NAME) --platform linux/amd64 --rm -it \
		-v "$(VOLUME_NAME):$(SRC_MNT)" \
		$(IMAGE_NAME) /bin/bash

run-container: volume-shell ## -- Kept for compatibility (debugging)
run: run-container ## -- Alias for run-container

volume-init: build-container volume-create ## Clone or update pve-kernel inside the volume (no mac bind mount)
	docker run --name $(CONTAINER_NAME) --platform linux/amd64 --rm -t \
		-v "$(VOLUME_NAME):$(SRC_MNT)" \
		$(IMAGE_NAME) /bin/bash -lc '\
			set -euo pipefail; \
			if [ ! -d "$(SRC_MNT)/.git" ]; then \
				echo "[INFO] Cloning pve-kernel into volume $(VOLUME_NAME)"; \
				git clone git://git.proxmox.com/git/pve-kernel.git $(SRC_MNT); \
			else \
				echo "[INFO] Updating existing pve-kernel repo in volume $(VOLUME_NAME)"; \
				cd $(SRC_MNT); \
				git fetch --all --tags; \
			fi; \
			git config --global init.defaultBranch main; \
			cd $(SRC_MNT) &&  git -c init.defaultBranch=main submodule update --init --recursive; \
		'

prep-source: build-container volume-init ## Create build dir + install build-deps from generated debian/control (in volume)
	@echo
	@echo "Running make clean && make build-dir-fresh inside the Docker volume..."
	@echo
	docker run --name $(CONTAINER_NAME) --platform linux/amd64 --rm -t \
		-v "$(VOLUME_NAME):$(SRC_MNT)" \
		$(IMAGE_NAME) /bin/bash -lc '\
			set -euo pipefail; \
			cd $(SRC_MNT); \
			make clean; \
			make build-dir-fresh; \
			BUILDDIR="$$(ls -d proxmox-kernel-* 2>/dev/null | head -n 1)"; \
			if [ -z "$$BUILDDIR" ] || [ ! -d "$$BUILDDIR" ]; then \
				echo "No build dir found (proxmox-kernel-*), exiting!"; \
				exit 1; \
			fi; \
			echo "[INFO] Using BUILDDIR=$$BUILDDIR"; \
			mk-build-deps -ir "$$BUILDDIR/debian/control"; \
		'

prep: prep-source ## -- Alias for prep-source

kernel: build-container volume-init ## Build kernel .deb packages inside the container (make deb) using the volume
	docker run --name $(CONTAINER_NAME) --platform linux/amd64 --rm -t \
		-v "$(VOLUME_NAME):$(SRC_MNT)" \
		$(IMAGE_NAME) /bin/bash -lc '\
			set -euo pipefail; \
			cd $(SRC_MNT); \
			make deb; \
		'

rebuild-kernel: build-container volume-init ## Clean and rebuild kernel .deb packages inside the container
	docker run --name $(CONTAINER_NAME) --platform linux/amd64 --rm -t \
		-v "$(VOLUME_NAME):$(SRC_MNT)" \
		$(IMAGE_NAME) /bin/bash -lc '\
			set -euo pipefail; \
			cd $(SRC_MNT); \
			make clean; \
			make deb; \
		'

export-debs: build-container volume-create ## Copy built .deb packages from the volume to ./build (bind mounted)
	@mkdir -p "$(OUTDIR)"
	docker run --name $(CONTAINER_NAME) --platform linux/amd64 --rm -t \
		-v "$(VOLUME_NAME):$(SRC_MNT):ro" \
		-v "$(OUTDIR):/out" \
		$(IMAGE_NAME) /bin/bash -lc '\
			set -euo pipefail; \
			shopt -s nullglob; \
			cd $(SRC_MNT); \
			DEBS=( *.deb ); \
			if [ "$${#DEBS[@]}" -eq 0 ]; then \
				echo "[WARN] No .deb files found at repository root. Searching under proxmox-kernel-* ..."; \
				DEBS=( proxmox-kernel-*/**/*.deb ); \
			fi; \
			if [ "$${#DEBS[@]}" -eq 0 ]; then \
				echo "[ERROR] No .deb files found to export."; \
				exit 1; \
			fi; \
			echo "[INFO] Exporting $${#DEBS[@]} .deb package(s) to /out"; \
			cp -v "$${DEBS[@]}" /out/; \
		'
	@echo
	@echo "------ Exported the .deb packages ------"
	@echo "Directory: $(OUTDIR)"
	@ls -l $(OUTDIR)
	@echo

all: prep-source kernel export-debs ## Full pipeline: init/prep -> build -> export artifacts

clean: ## Remove docker image (keeps the volume)
	docker stop $(CONTAINER_NAME) || true
	docker rmi $(IMAGE_NAME) >/dev/null 2>&1 || true

clean-all: ## Remove docker image and remove the volume (DESTROYS source/build state)
	docker stop $(CONTAINER_NAME) || true
	docker rmi $(IMAGE_NAME) >/dev/null 2>&1 || true
	docker volume rm -f $(VOLUME_NAME) >/dev/null 2>&1 || true

all-clean: clean-all ## Alias
