m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM docker.io/golang:1-buster AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Environment
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOOS=m4_ifdef([[CROSS_GOOS]], [[CROSS_GOOS]])
ENV GOARCH=m4_ifdef([[CROSS_GOARCH]], [[CROSS_GOARCH]])
ENV GOARM=m4_ifdef([[CROSS_GOARM]], [[CROSS_GOARM]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		file \
		tzdata

# Build Watchtower
ARG WATCHTOWER_TREEISH=v1.1.3
ARG WATCHTOWER_REMOTE=https://github.com/containrrr/watchtower.git
WORKDIR /go/src/watchtower/
RUN git clone "${WATCHTOWER_REMOTE:?}" ./
RUN git checkout "${WATCHTOWER_TREEISH:?}"
RUN git submodule update --init --recursive
RUN go build -o ./watchtower -ldflags "-s -w -X main.version=${WATCHTOWER_TREEISH:?}" ./main.go
RUN mv ./watchtower /usr/bin/watchtower
RUN file /usr/bin/watchtower
RUN /usr/bin/watchtower --help

##################################################
## "watchtower" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS watchtower
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Environment
ENV WATCHTOWER_TIMEOUT=30s
ENV WATCHTOWER_CLEANUP=true
ENV WATCHTOWER_ROLLING_RESTART=true

# The Watchtower container is identified by the presence of this label
LABEL com.centurylinklabs.watchtower=true

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Setup timezone
ENV TZ=UTC
RUN printf '%s\n' "${TZ:?}" > /etc/timezone \
	&& ln -snf "/usr/share/zoneinfo/${TZ:?}" /etc/localtime

# Copy Watchtower build
COPY --from=build --chown=root:root /usr/bin/watchtower /usr/bin/watchtower

ENTRYPOINT ["/usr/bin/watchtower"]
