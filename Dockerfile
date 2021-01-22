FROM alpine

RUN apk --no-cache add \
    bash \
    curl \
    iproute2 \
    libc6-compat

WORKDIR /find

RUN curl -Lo firecracker.tgz https://github.com/firecracker-microvm/firecracker/releases/download/v0.24.0/firecracker-v0.24.0-x86_64.tgz \
    && mkdir firecracker \
    && tar -xf firecracker.tgz -C firecracker \
    && chmod +x firecracker/firecracker-v0.24.0-x86_64 \
    && mv firecracker/firecracker-v0.24.0-x86_64 /usr/local/bin/firecracker

RUN curl -fsSL -o /find/vmlinux.bin https://storage.googleapis.com/anyfiddle-find/kernel/default-kernel-latest.bin

COPY start-firecracker.sh /usr/local/bin/start-firecracker
RUN chmod +x /usr/local/bin/start-firecracker

ENTRYPOINT ["/usr/local/bin/start-firecracker"]
