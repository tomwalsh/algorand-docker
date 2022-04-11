# Algorand Based Docker Container
This repo contains a Docker based setup for compiling and running an Algorand node.

## Basic Information
The Docker build uses a multistage build to compile Algorand, and then move the binaries to the production docker image when completed.

The image also makes use of the `gosu` application to drop privledges so that algod doesn't run as root.

Alogrand runs as the user "app" within the container. If you want to change this behavior you will also need to edit the user in the entrypoint.sh script.

The container runs on the mainnet for Algorand by default.

## Build the Image

```
docker build --no-cache -t algorand:latest .
```

## Run the Image
*assuming you used the build command above*
```
docker run algorand:latest
```

### Suggestions
It is suggested that you run this with a data volume or host volume so that you don't have to resync the node after every restart.

```
docker run -ti --rm -v [path to data folder]:/home/app/.algorand .
```
