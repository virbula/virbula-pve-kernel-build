FROM debian:trixie


ENV DEBIAN_FRONTEND=noninteractive

# Now apt can update with the Proxmox repo enabled
RUN apt-get update  -y \
  && apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    numactl \
    libnuma-dev \
    libssl-dev \
    libelf-dev \
    debianutils \
    sed \
    flex \
    bison \
    bc \
    libdw-dev \
    libiberty-dev \
    libudev-dev \
    lintian \
    asciidoc-base \
    quilt \
    kmod \
    rsync \
    cpio 


RUN apt-get install -y    \
      build-essential \
      debhelper   \
      pkg-config \
      python3-minimal \
      perl \
      dh-python \
      dh-sequence-python3   \
      dh-sequence-sphinxdoc \
      dh-sequence-sphinxdoc 


RUN apt-get install -y devscripts

#RUN rm -rf /var/lib/apt/lists/*

RUN apt-get install -y dwarves gawk libslang2-dev lz4 python3-dev xmlto zstd

WORKDIR /src

