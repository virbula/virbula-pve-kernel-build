# pve-kernel-build
Automated PVE Kernel Build With Docker Containers


# Steps

## 1. Build the docker container image used to compile the PVE Kernel source

* make build

or 

* make container

## 2. Clone (Check out from Proxmox pve-kernel git repo)  the pve-kernel source code, and check out the submodules

* make clone


## 3. Prepare the build directory and install build-dependencies in the build directory 

* make prep

It essentially does two things:
* make build-dir-refresh
* mk-build-deps -ir BUILD-DIR/debian/control

which creates the build directory,  and install build-dependencies in the actual build directory 
created in the first step.  You have to replace the BUILD-DIR with the actual build directory name.
The make file automates that to use the first directory found, which is correct most of the time. 



## 4. Build the actual .deb kernel packages, including the kernel and the header packages.

* make kernel 

It runs make deb in the pve-kernel directory after the preps are done. 


## 5. Make clean all and rebuild

You can clean up the tree, and rebuild the kernel as needed.  


