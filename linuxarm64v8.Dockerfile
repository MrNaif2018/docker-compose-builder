FROM arm64v8/python:3.7.10-stretch as builder
# Add env
ENV LANG C.UTF-8

# Enable cross-build for aarch64
#EnableQEMU COPY qemu-aarch64-static /usr/bin
RUN apt-get update && apt-get install -qq --no-install-recommends unzip

# Set the versions
ARG DOCKER_COMPOSE_VER
# docker-compose requires pyinstaller 3.5 (check github.com/docker/compose/requirements-build.txt)
# If this changes, you may need to modify the version of "six" below
ENV PYINSTALLER_VER 3.5
# "six" is needed for PyInstaller. v1.11.0 is the latest as of PyInstaller 3.5
ENV SIX_VER 1.11.0

# Install dependencies
RUN pip install --upgrade pip
RUN pip install six==$SIX_VER

# Compile the pyinstaller "bootloader"
# https://pyinstaller.readthedocs.io/en/stable/bootloader-building.html
WORKDIR /build/pyinstallerbootloader
RUN curl -fsSL https://github.com/pyinstaller/pyinstaller/releases/download/v$PYINSTALLER_VER/PyInstaller-$PYINSTALLER_VER.tar.gz | tar xvz >/dev/null \
    && cd PyInstaller*/bootloader \
    && python3 ./waf all

# Clone docker-compose
WORKDIR /build/dockercompose
RUN curl -fsSL https://github.com/docker/compose/archive/$DOCKER_COMPOSE_VER.zip > $DOCKER_COMPOSE_VER.zip \
    && unzip $DOCKER_COMPOSE_VER.zip

RUN cd compose-$DOCKER_COMPOSE_VER && mkdir ./dist \
    && pip install -r requirements.txt -r requirements-build.txt

RUN cd compose-$DOCKER_COMPOSE_VER \
    && echo "unknown" > compose/GITSHA \
    && pyinstaller docker-compose.spec \
    && mkdir /dist \
    && mv dist/docker-compose /dist/docker-compose

FROM arm64v8/debian:stretch-slim

COPY --from=builder /dist/docker-compose /tmp/docker-compose

# Copy out the generated binary
VOLUME /dist
CMD /bin/cp /tmp/docker-compose /dist/docker-compose