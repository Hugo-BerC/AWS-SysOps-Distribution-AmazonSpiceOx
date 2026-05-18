FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bc \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        cpio \
        curl \
        e2fsprogs \
        file \
        flex \
        gzip \
        libgmp-dev \
        libelf-dev \
        libmpc-dev \
        libmpfr-dev \
        libssl-dev \
        make \
        musl-tools \
        qemu-system-x86 \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["bash"]
