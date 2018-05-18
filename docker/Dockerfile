ARG version=xenial
FROM ubuntu:${version}

LABEL maintainer="frank.foerster@ime.fraunhofer.de"

RUN apt update && apt install --yes \
	build-essential \
	cpanminus \
	libdbi* \
	libdbd* \
	libdbix* \
	libposix-strftime-compiler-perl \
	libapache-logformat-compiler-perl \
	pbzip2 \
	mysql-client

RUN cpanm \
	Dancer2 \
        Dancer2::Plugin::DBIC \
	Bio::TreeIO \
	SVG::Graph
