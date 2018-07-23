ARG version=xenial
FROM ubuntu:${version}

ARG VERSION=master
ARG VCS_REF
ARG BUILD_DATE

RUN echo "VCS_REF: "${VCS_REF}", BUILD_DATE: "${BUILD_DATE}", VERSION: "${VERSION}

LABEL maintainer="frank.foerster@ime.fraunhofer.de" \
      description="Dockerfile providing our internal service webserver" \
      version="$VERSION" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/greatfireball/ime_bioinf_service_webserver"


RUN apt update && apt install --yes \
	build-essential \
	cpanminus \
	libdbi* \
	libdbd* \
	libdbix* \
	libposix-strftime-compiler-perl \
	libapache-logformat-compiler-perl \
	pbzip2 \
	pngquant \
	mysql-client

RUN cpanm install --force \
        Test::Time

RUN cpanm \
	Dancer2 \
	Dancer2::Plugin::DBIC \
	Dancer::Plugin::ProxyPath \
	Bio::TreeIO \
	SVG::Graph
