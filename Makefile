#SHELL := /bin/bash

# Variables
IMAGE_NAME = pve-kernel-builder
PWD = $(shell pwd)
SRC = $(PWD)/pve-kernel


.PHONY: help build-image build-kernel clean-all

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' |  sed -e 's/^/ /'

build: build-image

## build-image: Create the Docker container environment with all dependencies
build-image:
	cd pve-kernel; \
	docker buildx build --platform linux/amd64 -f ../Dockerfile -t $(IMAGE_NAME) .

## run-kernel: Run the compilation process inside the container to produce .deb packages
run-kernel:
	docker run --platform linux/amd64 --rm -t -v "$(PWD)/pve-kernel:/src" $(IMAGE_NAME) /bin/bash

## run-debian: Run the stock debian trixie container
run-debian:
	docker run --platform linux/amd64 --rm -t debian:trixie /bin/bash

## build-kernel-prep: Run make build-dir-fresh to create build-directory so that we got final packaging control files from the .in templates generated
build-kernel-prep:
	docker run --platform linux/amd64 --rm -v "$(PWD)/pve-kernel:/src" $(IMAGE_NAME) /bin/bash -c "make clean && make build-dir-fresh"

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
		"$(IMAGE_NAME)" \
		/bin/bash -lc \
                "mk-build-deps -ir $$BUILDDIR/debian/control"

## build-kernel: Run the compilation process inside the container to produce .deb packages
build-kernel:
	docker run --platform linux/amd64 --rm -it \
		-v "$(SRC):/src" \
		"$(IMAGE_NAME)" \
		/bin/bash -lc \
                "make deb"

## re-build-kernel: Clean up and Run the compilation process inside the container to produce .deb packages
re-build-kernel:
	docker run --platform linux/amd64 --rm -v "$(PWD)/pve-kernel:/src" $(IMAGE_NAME) /bin/bash -c "make clean && make"

## clean-all: Remove the Docker image and clean the local source tree
clean-all:
	cd pve-kernel; \
	-docker rmi $(IMAGE_NAME); \
	make clean
