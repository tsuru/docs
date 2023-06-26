FROM golang:1.20-alpine3.17 AS builder
COPY ./ /go/app/
RUN set -x \
    && cd /go/app\
    && CGO_ENABLED=0 go build -o server ./main.go

# NOTE: Tsuru doesn't support deploy of distroless container images.
FROM alpine:3.17

# You should always set the working dir so Tsuru will try to find the config
# files (Procfile, tsuru.yaml) from there.
WORKDIR /var/app

# Copying generated file from previous build stage \o/
COPY --from=builder /go/app/server /var/app/

# Copying app's config file to working dir.
COPY ./tsuru.yaml /var/app

# NOTE: Container runtime doesn't expand the env var ($PORT), so we have to
# call a shell interpreter to do so.
#
# See more: https://github.com/moby/moby/issues/5509
CMD ["sh", "-c", "/var/app/server -port $PORT"]
