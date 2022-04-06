###############
### STAGE 1 ###
###############

# Settings used in the Dockerfile to build the application
ARG GOLANG_IMAGE_VERSION=golang:alpine3.15
ARG ALPINE_IMAGE_VERSION=alpine:3.15

# Multistage build of the algorand application
FROM ${GOLANG_IMAGE_VERSION} AS builder

# Defaults for our build
ARG ALGO_PATH=/go/src/github.com/algorand/go-algorand
ARG GOSU_PATH=/go/src/github.com/tianon/gosu
ARG ALGO_VERSION=v3.5.1-stable
ARG GOSU_VERSION=1.14

# Install requirements to build the application
RUN apk update && apk upgrade
RUN apk add --no-cache boost-dev git bash make libtool autoconf automake gcc build-base cmake sqlite
RUN rm /var/cache/apk/* || true

# Setup the build path and set it as the working directory
RUN mkdir -p ${ALGO_PATH}
WORKDIR ${ALGO_PATH}

# Check out the code from the repo
RUN git -c advice.detachedHead=false clone --branch $ALGO_VERSION https://github.com/algorand/go-algorand.git ${ALGO_PATH}

# Build the application for use in the next stage
RUN make install

# Build gosu which we will use for our entrypoint application
# Setup the build path and set it as the working directory
RUN mkdir -p ${GOSU_PATH}
WORKDIR ${GOSU_PATH}

# Check out the gosu code to build from
RUN git -c advice.detachedHead=false clone --branch $GOSU_VERSION https://github.com/tianon/gosu.git ${GOSU_PATH}

# Build gosu - Run multiple commands because we don't care about the image size as it will be discarded.
RUN go mod download
RUN go mod verify
RUN go build -v -ldflags '-d -s -w' -o ${GOBIN}/bin/gosu

###############
### STAGE 2 ###
###############

# building the second stage of the application
FROM ${ALPINE_IMAGE_VERSION}

# Default user to run the application
ARG APP_USER=app
ARG ALGO_PATH=/go/src/github.com/algorand/go-algorand

# Copy over the application from the builder stage (stage 1)
COPY --from=builder ${ALGO_PATH}/tmp/dev_pkg/bin/algod /bin/algod
COPY --from=builder ${ALGO_PATH}/tmp/dev_pkg/bin/algokey /bin/algokey
COPY --from=builder ${ALGO_PATH}/tmp/dev_pkg/bin/algocfg /bin/algocfg
COPY --from=builder ${ALGO_PATH}/tmp/dev_pkg/bin/kmd /bin/kmd
COPY --from=builder ${ALGO_PATH}/tmp/dev_pkg/bin/goal /bin/goal
COPY --from=builder /bin/gosu /bin/gosu
# Copy in our entrypoint.sh
COPY ./entrypoint.sh /entrypoint.sh

# Install required applications and setup default user
# Group multiple RUN statements in a single command - this keeps the image as small as possible.
RUN apk add --update --no-cache \
	sed \
	curl \
	bash && \
	apk add --no-cache tzdata && \
	cp /usr/share/zoneinfo/America/New_York /etc/localtime && \
	addgroup --gid 1001 -S ${APP_USER} && \
	adduser --uid 1005 -S -G ${APP_USER} ${APP_USER} && \
	chown -R ${APP_USER} /bin/algod /bin/goal /bin/algokey /bin/algocfg /bin/kmd && \
	mkdir -p /home/${APP_USER}/.algorand && \
    chown -R ${APP_USER}:${APP_USER} /home/${APP_USER}/.algorand && \
    chmod +x /bin/gosu /entrypoint.sh && \
	chown -R ${APP_USER} /home/${APP_USER}/

# Copy over the genesis file for the mainnet
COPY --from=builder ${ALGO_PATH}/tmp/dev_pkg/genesis/mainnet/genesis.json /home/${APP_USER}/genesis.json

# Allow port 4160 for communication with the chain
# Allow port 8080 for RPC communication
EXPOSE 4160
EXPOSE 8080

# Set the pocket data folder to be a data volume
VOLUME /home/${APP_USER}/.algorand

# Set our working directory to be the user's 
WORKDIR /home/${APP_USER}

# Set the environment value for algod to use the data directory
ENV ALGORAND_DATA=/home/${APP_USER}/.algorand

ENTRYPOINT ["/entrypoint.sh"]
