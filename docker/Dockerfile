# Image TinyOS (tinyos-main) + nesC 1.4 + TOSSIM
FROM --platform=linux/amd64 ubuntu:16.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential bison flex emacs-nox gperf python2.7 python2.7-dev python python3 python3-dev \
    git ca-certificates make autoconf automake libtool pkg-config default-jdk-headless \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/tinyos/nesc.git /opt/nesc \
    && cd /opt/nesc && ./Bootstrap && ./configure && make && make install
RUN git clone --depth 1 https://github.com/tinyos/tinyos-main.git /opt/tinyos-main \
    && cd /opt/tinyos-main/tools && ./Bootstrap && ./configure && make && make install
ENV TOSROOT=/opt/tinyos-main \
    TOSDIR=/opt/tinyos-main/tos \
    MAKERULES=/opt/tinyos-main/support/make/Makerules \
    PYTHONPATH=/opt/tinyos-main/support/sdk/python:.
WORKDIR /work
