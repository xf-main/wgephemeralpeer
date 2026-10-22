# FROM ubuntu:noble-20260113 AS cert
FROM ubuntu@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b AS cert

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates

# FROM ubuntu:noble-20260113 AS apt
FROM ubuntu@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b AS apt

ENV APT_SNAPSHOT=20260205T000000Z
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

COPY --from=cert /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

RUN echo "APT::Snapshot ${APT_SNAPSHOT};" | tee /etc/apt/apt.conf.d/50snapshot

# Deps for build.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    make \
    zip

# Cleanup for reproducible container.
RUN apt-get clean \
  && find /var/log/apt -type f -delete \
  && rm /var/log/dpkg.log /var/log/alternatives.log /var/cache/ldconfig/aux-cache

# FROM ghcr.io/mullvad/wgephemeralpeer-apt:50e5e984635b29313ad0ce3af35fbd639de22706 AS build
# The following FROM-line can be substituted by sed, by matching regex: ^FROM ghcr.io/.* AS build$,
# take care to ensure working substitution when making changes.
FROM ghcr.io/mullvad/wgephemeralpeer-apt@sha256:6490c34b72071133f254364ac63c669620a412563123466bb2949ac56d29d2f2 AS build

ENV PATH="$PATH:/usr/local/go/bin:/root/go/bin"

# The SHA256 checksum used to verify the go archive can be found at https://go.dev/dl/

ENV GO_FILENAME=go1.26.10.linux-amd64.tar.gz
ENV GO_FILEHASH=ccfe7ae822d2c2f41f4fe7c956199967a4dac22d0ee0d2b2bfdb440aab3b20c5

ENV GOCI_URL=https://github.com/golangci/golangci-lint/releases/download/v2.10.1/golangci-lint-2.10.1-linux-amd64.deb
ENV GOCI_FILEHASH=8aa9b3aa14f39745eeb7fc7ff50bcac683e785397d1e4bc9afd2184b12c4ce86

RUN curl -s -L https://go.dev/dl/${GO_FILENAME} >/tmp/${GO_FILENAME} \
  && echo ${GO_FILEHASH} /tmp/${GO_FILENAME} | sha256sum --check \
  && tar -C /usr/local -xzf /tmp/${GO_FILENAME}

FROM build AS test

RUN go install golang.org/x/vuln/cmd/govulncheck@latest \
  && curl -s -L ${GOCI_URL} >/tmp/goci.deb \
  && echo ${GOCI_FILEHASH} /tmp/goci.deb | sha256sum --check \
  && dpkg -i /tmp/goci.deb
