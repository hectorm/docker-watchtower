m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM docker.io/golang:1-buster AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Environment
ENV GO111MODULE=on
ENV CGO_ENABLED=0

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		file \
		tzdata

# Build Watchtower
ARG WATCHTOWER_TREEISH=v0.3.10
RUN go get -v -d "github.com/containrrr/watchtower@${WATCHTOWER_TREEISH:?}"
RUN cd "${GOPATH:?}/pkg/mod/github.com/containrrr/watchtower@${WATCHTOWER_TREEISH:?}" \
	&& export GOOS=m4_ifdef([[CROSS_GOOS]], [[CROSS_GOOS]]) \
	&& export GOARCH=m4_ifdef([[CROSS_GOARCH]], [[CROSS_GOARCH]]) \
	&& export GOARM=m4_ifdef([[CROSS_GOARM]], [[CROSS_GOARM]]) \
	&& export LDFLAGS="-s -w -X main.version=${WATCHTOWER_TREEISH:?}" \
	&& go build -o ./watchtower -ldflags "${LDFLAGS:?}" ./main.go \
	&& mv ./watchtower /usr/bin/watchtower \
	&& file /usr/bin/watchtower \
	&& /usr/bin/watchtower --help

##################################################
## "watchtower" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:18.04]], [[FROM docker.io/ubuntu:18.04]]) AS watchtower
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Environment
ENV WATCHTOWER_TIMEOUT=30s
ENV WATCHTOWER_CLEANUP=true

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
RUN ln -snf "/usr/share/zoneinfo/${TZ:?}" /etc/localtime
RUN printf '%s\n' "${TZ:?}" > /etc/timezone

# Copy Watchtower build
COPY --from=build --chown=root:root /usr/bin/watchtower /usr/bin/watchtower

ENTRYPOINT ["/usr/bin/watchtower"]
