FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bc \
        binutils \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        cpio \
        curl \
        debootstrap \
        e2fsprogs \
        file \
        flex \
        gnupg \
        gzip \
        libgmp-dev \
        libelf-dev \
        libmpc-dev \
        libmpfr-dev \
        libssl-dev \
        make \
        musl-tools \
        perl \
        qemu-system-x86 \
        libtext-template-perl \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["bash"]
