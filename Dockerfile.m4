m4_changequote([[, ]])

m4_ifdef([[CROSS_QEMU]], [[
##################################################
## "qemu-user-static" stage
##################################################

FROM ubuntu:18.04 AS qemu-user-static
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends qemu-user-static
]])

##################################################
## "build-watchtower" stage
##################################################

FROM golang:1-stretch AS build-watchtower
m4_ifdef([[CROSS_QEMU]], [[COPY --from=qemu-user-static CROSS_QEMU CROSS_QEMU]])

# Environment
ENV GO111MODULE=on
ENV CGO_ENABLED=0

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		file \
		tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Build Watchtower
ARG WATCHTOWER_TREEISH=v0.3.3
RUN go get -v -d "github.com/containrrr/watchtower@${WATCHTOWER_TREEISH}"
RUN cd "${GOPATH}/pkg/mod/github.com/containrrr/watchtower@${WATCHTOWER_TREEISH}" \
	&& export GOOS=m4_ifdef([[CROSS_GOOS]], [[CROSS_GOOS]]) \
	&& export GOARCH=m4_ifdef([[CROSS_GOARCH]], [[CROSS_GOARCH]]) \
	&& export GOARM=m4_ifdef([[CROSS_GOARM]], [[CROSS_GOARM]]) \
	&& export LDFLAGS="-s -w -X main.version=${WATCHTOWER_TREEISH}" \
	&& go build -o ./watchtower -ldflags "${LDFLAGS}" ./main.go \
	&& mv ./watchtower /usr/bin/watchtower \
	&& file /usr/bin/watchtower \
	&& /usr/bin/watchtower --version

##################################################
## "watchtower" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM CROSS_ARCH/ubuntu:18.04]], [[FROM ubuntu:18.04]]) AS watchtower
m4_ifdef([[CROSS_QEMU]], [[COPY --from=qemu-user-static CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Copy Watchtower build
COPY --from=build-watchtower --chown=root:root /usr/bin/watchtower /usr/bin/watchtower

ENTRYPOINT ["/usr/bin/watchtower"]
