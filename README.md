# Virbula pve-kernel-build
Automated PVE Kernel Build With Docker Containers, used by the Virbula team for building and customizing the PVE Kernel for experimentation.

Important Note: You need to make sure you docker instance provides enough disk space for the container.  On Docker Desktop, this is a resource limit setting you can set in the Settings configuration section.  Currently you need roughly 80GB of disk space in the container to build the PVE Kernel inside the container. 

# License

AGPL v3.0 license, open source as Proxmox PVE license. 


# Steps

## 0.  Make sure you have enough disk space in the host and inside the container

The build process requires roughly 100GB of space in total, including space for code, and for compliation.  What this means is that you need enough space inside the container for the /src volume, used to store the source code and compilation objects, and the / partition inside the container (specifically the /tmp file system). 

The build process creates a docker volume, which is limited by the Docker Desktop (if this is what you are using), or by the root partition used by the docker daemon. 
For example, on a Debian Linux,  the docker volume data resides typically under /var/lib/docker. 

* Make sure you have at least 80GB for the docker volumen used for source code and compilation object. 
* Make sure your host for running docker has enough space 80GB under /var/lib/docker (if Linux), or for Docker Desktop (set resource limit for storage to at least 80GB)

## 1. Build the docker container image used to compile the PVE Kernel source

* make build

or 

* make container

## 2. Prepare the build directory and install build-dependencies in the build directory 

* make prep

It essentially does the following things:
* clones the git repos into a docker volume
* make build-dir-refresh
* mk-build-deps -ir BUILD-DIR/debian/control

which creates the build directory,  and install build-dependencies in the actual build directory 
created in the first step.  You have to replace the BUILD-DIR with the actual build directory name.
The make file automates that to use the first directory found, which is correct most of the time. 



## 3. Build the actual .deb kernel packages, including the kernel and the header packages.

* make kernel 

It runs make deb in the pve-kernel directory after the preps are done. 


## 4. Make clean all and rebuild

You can clean up the tree, and rebuild the kernel as needed.  


