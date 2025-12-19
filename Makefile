# Makefile for building Proxmox VE kernel packages in a Docker build environment

SHELL := /bin/bash

# Variables
IMAGE_NAME := pve-kernel-builder
PWD        := $(shell pwd)
SRC        := $(PWD)/pve-kernel

.PHONY: help clone build-container build run-container run prep-source prep kernel rebuild-kernel clean clean-all run

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN { FS=":.*##" } \
		/^[a-zA-Z0-9_.-]+:.*##/ { \
			printf "  %-20s %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)

clone: ## Clone the pve-kernel source code from the Proxmox git repo
	git clone git://git.proxmox.com/git/pve-kernel.git
	cd pve-kernel && git submodule update --init --recursive


build-container: ## Create the Docker container image (linux/amd64) with all the build tools which can be used to compile the PVE kernel
	cd pve-kernel; \
	docker buildx build --platform linux/amd64 -f ../Dockerfile -t $(IMAGE_NAME) .

build: build-container ## -- Alias for build-container

run-container: ## Run the build container with an interactive bash shell (debugging)
	docker run --platform linux/amd64 --rm -t \
		-v "$(PWD)/pve-kernel:/src" \
		$(IMAGE_NAME) /bin/bash

run: run-container ## -- Alias for run-container


prep-source:  ## Create build dir and install build-deps from generated debian/control
	@echo
	@echo "Running make build-dir-fresh to create build directory and packaging control files"
	@echo
	docker run --platform linux/amd64 --rm \
		-v "$(PWD)/pve-kernel:/src" \
		$(IMAGE_NAME) /bin/bash -c "make clean && make build-dir-fresh"

	@set -e; \
	BUILDDIR=""; \
	cd pve-kernel; \
	for d in proxmox-kernel-*; do \
		[ -d "$$d" ] || continue; \
		case "$$d" in \
			proxmox-kernel-[0-9]*.[0-9]*.[0-9]*) \
				BUILDDIR="$$d"; \
				echo "BUILDDIR=$$BUILDDIR"; \
				break ;; \
		esac; \
	done; \
	if [ ! -d "$$BUILDDIR" ]; then \
		echo "No build dir found, exiting!"; \
		exit 1; \
	fi; \
	docker run --platform linux/amd64 --rm -it \
		-v "$(SRC):/src" \
		$(IMAGE_NAME) /bin/bash -lc \
		"mk-build-deps -ir $$BUILDDIR/debian/control"

prep: prep-source ## -- Alias for prep-source

kernel: ## Build kernel .deb packages inside the container (make deb)
	docker run --platform linux/amd64 --rm -it \
		-v "$(SRC):/src" \
		$(IMAGE_NAME) /bin/bash -lc \
		"make deb"

rebuild-kernel: ## Clean and rebuild kernel .deb packages inside the container
	docker run --platform linux/amd64 --rm \
		-v "$(PWD)/pve-kernel:/src" \
		$(IMAGE_NAME) /bin/bash -c "make clean && make deb"

clean: ## Run make clean in pve-kernel and remove Docker image (keeps source tree)
	cd pve-kernel; \
	-docker rmi $(IMAGE_NAME); \
	make clean

clean-all: ## Remove Docker image and delete the local pve-kernel source tree
	cd pve-kernel; \
	-docker rmi $(IMAGE_NAME); \
	make clean
	rm -rf pve-kernel

