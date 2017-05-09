#!/bin/bash
#
# Run voodoo in a container
#
# This script will attempt to mirror the host paths by using volumes for the
# following paths:
#   * $(pwd)
#   * $(dirname $COMPOSE_FILE) if it's set
#   * $HOME if it's set
#
# You can add additional volumes (or any docker run options) using
# the $COMPOSE_OPTIONS environment variable.
#


set -e

VERSION="1.11.2"
IMAGE="voodoo:3.0"
VD_USER="voodoo"
VD_SCRIPT="/opt/bin/voodoo"
DOCKERID=$(id -g "docker")

if [ "$USER" == "$VD_USER" ]; then
   echo "user is $VD_USER"
else 
  echo "user is NOT $VD_USER"
  if [ $(grep -c $VD_USER "/etc/passwd") -ne 0 ]; then
     echo "$VD_USER exists"
  else
     echo "$VD_USER does not exist"
     if [ $(grep -c "$VD_USER" "/etc/group") -ne 0 ]; then
        echo "$VD_USER group exists"
     else
	echo "$VD_USER group does not exist"
      	sudo groupadd -g 1000 "$VD_USER"
     fi
     sudo useradd -u 1000 -g "$VD_USER" -p "$VD_USER" "$VD_USER"
     sudo usermod -a -G docker "$VD_USER"
     echo "user $VD_USER added as member of group $VD_USER and docker"

  fi
  echo "restarting as $VD_USER"
  exec su "$VD_USER" "$VD_SCRIPT" "$@"	
fi

# Setup options for connecting to docker host
if [ -z "$DOCKER_HOST" ]; then
    DOCKER_HOST="/var/run/docker.sock"
fi
if [ -S "$DOCKER_HOST" ]; then
    DOCKER_ADDR="-v $DOCKER_HOST:$DOCKER_HOST -e DOCKER_HOST"
else
    DOCKER_ADDR="-e DOCKER_HOST -e DOCKER_TLS_VERIFY -e DOCKER_CERT_PATH"
fi


# Setup volume mounts for compose config and context
if [ "$(pwd)" != '/' ]; then
    VOLUMES="-v $(pwd):$(pwd)"
fi

if [ -n "$HOME" ]; then
    VOLUMES="$VOLUMES -v $HOME:$HOME" # mount $HOME in $HOME[/root] to share docker.config and the voodoo files
fi

# Only allocate tty if we detect one
if [ -t 1 ]; then
    DOCKER_RUN_OPTIONS="-t"
fi
if [ -t 0 ]; then
    DOCKER_RUN_OPTIONS="$DOCKER_RUN_OPTIONS -i"
fi
DOCKER_RUN_OPTIONS="$DOCKER_RUN_OPTIONS -e USERID=$UID -e USERNAME=$USER -e DOCKERID=$DOCKERID"
exec docker run --rm $DOCKER_RUN_OPTIONS $DOCKER_ADDR $COMPOSE_OPTIONS $VOLUMES -w "$(pwd)" $IMAGE "$@"
