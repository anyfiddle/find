FROM alpine

RUN apk --no-cache add \
    curl \
    iproute2 \
    libc6-compat

WORKDIR /find

RUN curl -Lo firectl https://firectl-release.s3.amazonaws.com/firectl-v0.1.0 \
    && curl -Lo firectl.sha256 https://firectl-release.s3.amazonaws.com/firectl-v0.1.0.sha256 \
    && sha256sum -c firectl.sha256 \
    && chmod +x firectl \
    && mv firectl /usr/local/bin/firectl

RUN curl -Lo firecracker.tgz https://github.com/firecracker-microvm/firecracker/releases/download/v0.24.0/firecracker-v0.24.0-x86_64.tgz \
    && mkdir firecracker \
    && tar -xf firecracker.tgz -C firecracker \
    && chmod +x firecracker/firecracker-v0.24.0-x86_64 \
    && mv firecracker/firecracker-v0.24.0-x86_64 /usr/local/bin/firecracker

RUN curl -fsSL -o /find/vmlinux.bin https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin
RUN curl -fsSL -o /find/rootfs.ext4 https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4

COPY start-firecracker.sh /usr/local/bin/start-firecracker
RUN chmod +x /usr/local/bin/start-firecracker

CMD ["/bin/sh", "-c", "/usr/local/bin/start-firecracker"]
