#SHELL := /bin/bash

# Variables
IMAGE_NAME = pve-kernel-builder
PWD = $(shell pwd)
SRC = $(PWD)/pve-kernel


.PHONY: help build container clone prep prep-source kernel rebuild-kernel clean clean-all run

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' |  sed -e 's/^/ /'


## clone:  Clone the pve-kernel source code from the proxmox git repo
clone:
	git clone git://git.proxmox.com/git/pve-kernel.git
	cd pve-kernel && git submodule update --init --recursive

## build:  Same as container,  build the docker container used to compile the PVE Kernel
build: container

## container: Create the Docker container environment with all dependencies
container:
	cd pve-kernel; \
	docker buildx build --platform linux/amd64 -f ../Dockerfile -t $(IMAGE_NAME) .

## run-container: Run the container used to compile the kernel with bash shell, useful for debugging
run-container:
	docker run --platform linux/amd64 --rm -t -v "$(PWD)/pve-kernel:/src" $(IMAGE_NAME) /bin/bash

## prep-source: Same as prep
prep-source: prep

## prep: Run make build-dir-fresh to create build-directory so that we got final packaging control files from the .in templates generated
prep:
	@echo 
	@echo "Running make build-dir-fresh to create build directory and get the packaging control files from the .in templates"
	@echo 
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

## kernel: Run the compilation process inside the container to produce .deb packages
kernel:
	docker run --platform linux/amd64 --rm -it \
		-v "$(SRC):/src" \
		"$(IMAGE_NAME)" \
		/bin/bash -lc \
                "make deb"

## rebuild-kernel: Clean up and Run the compilation process inside the container to produce .deb packages
rebuild-kernel:
	docker run --platform linux/amd64 --rm -v "$(PWD)/pve-kernel:/src" $(IMAGE_NAME) /bin/bash -c "make clean && make deb"


## clean:  run a make clean inside the pve-kernel directory, this does not remove the source tree
clean: 
	cd pve-kernel; \
	-docker rmi $(IMAGE_NAME); \
	make clean; \


## clean-all: Remove the Docker image and clean the local source tree completely, leaving only this meta git repo
clean-all:
	cd pve-kernel; \
	-docker rmi $(IMAGE_NAME); \
	make clean


	rm -rf pve-kernel
