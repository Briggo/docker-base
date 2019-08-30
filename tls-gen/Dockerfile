FROM alpine:3.9

# Install Updates
RUN apk update
RUN apk upgrade
RUN apk add --no-cache --virtual .build-deps

# Install base and dev packages
RUN apk add bash git make groff less py3-lxml python3 py-pip openssl curl openssh

# Install build related packages
RUN apk add --no-cache --virtual=build-dependencies \
	autoconf \
	automake \
	freetype-dev \
	g++ \
	gcc \
	jpeg-dev \
	lcms2-dev \
	libffi-dev \
	libpng-dev \
	libwebp-dev \
	linux-headers \
	openjpeg-dev \
	openssl-dev \
	python3-dev \
	tiff-dev \
	zlib-dev

# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Install pip packages
RUN python3 -m ensurepip && \
 	rm -r /usr/lib/python*/ensurepip && \
 	ln -sf /usr/bin/pip3 /usr/bin/pip

RUN pip install --no-cache-dir -U pip setuptools
RUN pip install --upgrade pip

RUN pip install -U \
	configparser \
	ndg-httpsclient \
	notify \
	paramiko \
	pillow \
	psutil \
	pyopenssl \
	requests \
	setuptools \
	urllib3 \
	virtualenv

# Clean Up
RUN apk --purge -v del py-pip
RUN apk del --purge build-dependencies
RUN rm /var/cache/apk/*
RUN rm -rf /root/.cache /tmp/*

# Install TLS-Gen
RUN git clone https://github.com/michaelklishin/tls-gen /tls-gen
ADD ./files/generate.sh /generate.sh
RUN chmod 0755 /generate.sh 
RUN mkdir -p /tls-result