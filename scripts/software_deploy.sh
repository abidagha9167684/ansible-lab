#!/bin/bash
# Install, remove or upgrade an Ubuntu package on a client from the Admin machine over SSH.
# Usage: ./software_deploy.sh PACKAGE install|remove|upgrade

CLIENT="ubuntu@CLIENT_PRIVATE_IP"   # replace with your client's user@private-ip
KEY="/adminkey"                      # path to the SSH private key on the Admin machine

PACKAGE="$1"
ACTION="$2"

if [ "$ACTION" = "install" ]; then
  ssh -i "$KEY" "$CLIENT" "sudo apt update && sudo apt install -y $PACKAGE"

elif [ "$ACTION" = "remove" ]; then
  ssh -i "$KEY" "$CLIENT" "sudo apt remove -y $PACKAGE"

elif [ "$ACTION" = "upgrade" ]; then
  ssh -i "$KEY" "$CLIENT" "sudo apt update && sudo apt install --only-upgrade -y $PACKAGE"

else
  echo "Usage:"
  echo "./software_deploy.sh PACKAGE install"
  echo "./software_deploy.sh PACKAGE remove"
  echo "./software_deploy.sh PACKAGE upgrade"
fi
