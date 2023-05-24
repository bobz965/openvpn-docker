# Smallest base image
#https://hub.docker.com/_/alpine/tags

#FROM --platform=linux/amd64 alpine:latest
FROM alpine:latest

ADD VERSION .

# Install needed packages
RUN echo "http://dl-4.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories && \
    echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    apk update && apk add openssl easy-rsa openvpn iptables bash && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

# Configure tun
RUN mkdir -p /dev/net && \
     mknod /dev/net/tun c 10 200 

COPY setup /etc/openvpn/setup/
RUN mkdir -p /etc/openvpn/certs && chmod +x /etc/openvpn/setup/*.sh

