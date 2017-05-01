FROM frolvlad/alpine-glibc:alpine-3.5_glibc-2.25

# create the required directories
RUN mkdir -p /opt/startorio /opt/factorio

# Set the version
RUN echo "0.15.4" >> /opt/factorio/factorio.version

# set the directory for the build
WORKDIR /opt/startorio

# copy the required files
COPY LICENSE /opt/startorio/LICENSE
COPY startorio.cabal /opt/startorio
COPY src /opt/startorio/src
COPY factorio.crt /opt/startorio/factorio.crt

# add the testing repositories of alpine (for ghc & cabal)
RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# build and install the binary, then clean up
RUN apk add --update --no-cache curl musl-dev ghc@testing cabal@testing && \
    cabal update && \
    cabal install && \
    cabal build --ghc-options='-optl-static -optl-pthread' && \
    cp /opt/startorio/dist/build/startorio/startorio /opt/factorio/startorio && \
    curl -sSL --cacert /opt/startorio/factorio.crt https://www.factorio.com/get-download/$(cat /opt/factorio/factorio.version)/headless/linux64 -o /opt/startorio/factorio_headless_x64.tar.xz && \
    tar -x -J -C /opt -f /opt/startorio/factorio_headless_x64.tar.xz && \
    apk del curl musl-dev ghc cabal && \
    rm -rf /root/.ghc /root/.cabal /var/cache/apk/* /opt/startorio

# set the directory for the runtime
WORKDIR /opt/factorio

# create the config template
COPY server-settings.template.json /opt/factorio/server-settings.template.json

# the start command is our binary
CMD [ "/opt/factorio/startorio" ]

# define the volumes
VOLUME /opt/factorio/saves /opt/factorio/mods

# expose the required ports
EXPOSE 34197/udp
EXPOSE 27015/tcp

