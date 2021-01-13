FROM ubuntu

WORKDIR /workspace

RUN apt-get update && apt-get install -y \
	curl \
	build-essential \
    debootstrap \
    docker.io \
	git \
	&& rm -rf /var/lib/apt/lists/*

COPY create-rootfs.sh create-rootfs.sh

VOLUME /output

ENTRYPOINT ["./create-rootfs.sh"]